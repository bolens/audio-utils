#!/usr/bin/env python3
"""Prepare exact-source GHCR candidates; production activation requires the server broker."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess

REPOSITORY = "bolens/audio-utils"
IMAGE = f"ghcr.io/{REPOSITORY}"
OUTPUT = Path(".woodpecker-out")


class PublicationDisabled(Exception):
    """The owning host has not enabled the new publication owner."""


def sanitized_environment():
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("GH_", "GITHUB_", "GIT_", "CI_NETRC_", "CURL_TRACE", "CURL_VERBOSE"))
                   and key not in {"SSH_ASKPASS", "WOODPECKER_PUBLISH_LEASE"}}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                       GIT_TERMINAL_PROMPT="0")
    return environment


def run(*args, **kwargs):
    kwargs.setdefault("env", sanitized_environment())
    return subprocess.run(args, check=True, text=True, capture_output=True,
                          timeout=120, **kwargs).stdout.strip()


_GITHUB_CREDENTIAL = None
CREDENTIAL_ENDPOINT = "https://woodpecker.bolens.dev/publisher/credentials"


def github_environment():
    """Redeem a queued lease at execution time; keep the short-lived token in memory."""
    import datetime
    import math
    import secrets
    import time
    import urllib.request
    global _GITHUB_CREDENTIAL
    if _GITHUB_CREDENTIAL is None or _GITHUB_CREDENTIAL[1] - time.time() < 120:
        lease = os.environ.get("WOODPECKER_PUBLISH_LEASE", "")
        sha = os.environ.get("CI_COMMIT_SHA", "")
        if not lease or not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise ValueError("missing publication lease or source identity")
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None
        request = urllib.request.Request(CREDENTIAL_ENDPOINT,
            data=json.dumps({"lease": lease, "repository": REPOSITORY,
                             "commit": sha, "purpose": "github",
                             "request_id": secrets.token_hex(16)}).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
                record = json.load(response)
            token = record["token"]
            expires = record["expires_at"]
            if isinstance(expires, (int, float)):
                expiry = float(expires)
            else:
                parsed = datetime.datetime.fromisoformat(expires.replace("Z", "+00:00"))
                if parsed.tzinfo is None:
                    raise ValueError("broker expiry requires a timezone")
                expiry = parsed.timestamp()
            if (not isinstance(token, str) or not token
                    or any(ord(character) < 33 or ord(character) > 126 for character in token)
                    or not math.isfinite(expiry) or expiry - time.time() < 120):
                raise ValueError("invalid broker credential")
        except Exception:
            # Never expose HTTP response bodies, request objects, lease or token.
            raise RuntimeError("publication credential redemption failed") from None
        _GITHUB_CREDENTIAL = (token, expiry)
    environment = sanitized_environment()
    environment.update(GH_TOKEN=_GITHUB_CREDENTIAL[0], GH_HOST="github.com",
                       GH_PROMPT_DISABLED="1", GH_NO_UPDATE_NOTIFIER="1",
                       GIT_TERMINAL_PROMPT="0")
    return environment


def api(path, method="GET", data=None):
    args = ["gh", "api", "--method", method, path]
    if data is not None:
        args += ["--input", "-"]
    raw = run(*args, input=json.dumps(data) if data is not None else None,
              env=github_environment())
    return json.loads(raw) if raw else None


def context():
    expected = {"CI_FORGE_TYPE": "github", "CI_FORGE_URL": "https://github.com",
                "CI_REPO": REPOSITORY}
    for key, value in expected.items():
        if os.environ.get(key) != value:
            raise ValueError(f"publication denied: unexpected {key}")
    event = os.environ.get("CI_PIPELINE_EVENT")
    tag = os.environ.get("CI_COMMIT_TAG", "")
    if REPOSITORY == "bolens/audio-utils":
        if (event != "push" or os.environ.get("CI_COMMIT_BRANCH") != "main"
                or os.environ.get("CI_COMMIT_REF") != "refs/heads/main" or tag):
            raise ValueError("publication denied: expected canonical main push")
    elif event != "tag" or not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", tag):
        raise ValueError("publication denied: expected immutable release tag")
    elif os.environ.get("CI_COMMIT_REF") != f"refs/tags/{tag}":
        raise ValueError("publication denied: mismatched tag ref")
    sha = os.environ.get("CI_COMMIT_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or run("git", "rev-parse", "HEAD") != sha:
        raise ValueError("publication denied: checkout differs from event")
    if run("git", "status", "--porcelain", "--untracked-files=no"):
        raise ValueError("publication denied: tracked source was modified")
    return sha, tag


def guard():
    sha, tag = context()
    try:
        setting = api(f"repos/{REPOSITORY}/actions/variables/WOODPECKER_PUBLISHING")
    except subprocess.CalledProcessError:
        raise PublicationDisabled("Woodpecker publication setting unavailable; no writes") from None
    if setting.get("value") != "true":
        raise PublicationDisabled("Woodpecker publication disabled; no writes")
    if tag:
        ref = api(f"repos/{REPOSITORY}/git/ref/tags/{tag}")["object"]
        if ref["type"] != "tag":
            raise ValueError("release requires an annotated signed tag")
        signed = api(f"repos/{REPOSITORY}/git/tags/{ref['sha']}")
        if not signed.get("verification", {}).get("verified"):
            raise ValueError("release tag signature was not verified")
        if signed["object"].get("type") != "commit" or signed["object"].get("sha") != sha:
            raise ValueError("release tag target differs from event source")
        if api(f"repos/{REPOSITORY}/compare/{sha}...main")["status"] not in {"ahead", "identical"}:
            raise ValueError("release source is not reachable from canonical main")
        version = json.loads(Path("package.json").read_text())["version"]
        if tag != f"v{version}":
            raise ValueError("release tag differs from package.json version")
    elif api(f"repos/{REPOSITORY}/commits/main")["sha"] != sha:
        raise ValueError("superseded main candidate")
    return sha, tag


def prepare():
    sha, tag = guard()
    OUTPUT.mkdir(exist_ok=True)
    version = tag[1:] if tag else f"sha-{sha}"
    number = os.environ.get("CI_PIPELINE_NUMBER", "")
    if not re.fullmatch(r"[1-9][0-9]*", number):
        raise ValueError("invalid pipeline identity")
    candidate = f"candidate-{sha}-{number}"
    # Neither final identity nor a retry of this candidate may overwrite tags.
    # Serialized publication ownership is still required: registry tag APIs do
    # not provide an atomic compare-and-set between this check and a later push.
    for existing in (version, candidate):
        probe = subprocess.run(["skopeo", "inspect", f"docker://{IMAGE}:{existing}"],
                               text=True, capture_output=True, check=False, timeout=120,
                               env=sanitized_environment())
        if probe.returncode == 0:
            raise ValueError("immutable image tag already exists; inspect before recovery")
        if "manifest unknown" not in probe.stderr.lower() and "name unknown" not in probe.stderr.lower():
            raise ValueError("could not establish absence of immutable candidate")
    (OUTPUT / "kaniko.env").write_text(f"PLUGIN_TAGS={candidate}\n")


def manifest():
    sha, tag = guard()
    digest = (OUTPUT / "image.digest").read_text().strip()
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("invalid candidate digest")
    image = json.loads(run("skopeo", "inspect", f"docker://{IMAGE}@{digest}"))
    labels = image.get("Labels") or {}
    if (image.get("Digest") != digest or labels.get("org.opencontainers.image.revision") != sha
            or labels.get("org.opencontainers.image.source") != f"https://github.com/{REPOSITORY}"):
        raise ValueError("published candidate identity mismatch")
    record = {"repository": REPOSITORY, "commit": sha, "tag": tag,
              "image": IMAGE, "digest": digest,
              "builder": os.environ["CI_PIPELINE_URL"], "status": "candidate-only"}
    (OUTPUT / "image-manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    # Signing, runtime acceptance and alias/release promotion are intentionally
    # separate: a successful build does not establish these guarantees.
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["guard", "prepare", "manifest"])
    args = parser.parse_args()
    {"guard": guard, "prepare": prepare, "manifest": manifest}[args.phase]()


if __name__ == "__main__":
    try:
        main()
    except PublicationDisabled as disabled:
        print(disabled)
        raise SystemExit(78) from None
