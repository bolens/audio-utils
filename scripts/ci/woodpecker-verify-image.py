#!/usr/bin/env python3
"""Accept and promote the exact native Audio image through a thin Docker exception."""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

from woodpecker_native_status import wait_for_native_success

REPOSITORY = "bolens/audio-utils"
IMAGE = "ghcr.io/" + REPOSITORY
WORKFLOWS = ["woodpecker", "tools", "fedora", "mcp-minimum", "functional-apt", "functional-latest", "publishing"]
OUTPUT = Path(".woodpecker-out/bridge")


def environment(auth=False):
    result = {key: value for key, value in os.environ.items()
              if not key.startswith(("GH_", "GITHUB_", "GIT_", "CI_NETRC_", "CURL_TRACE", "CURL_VERBOSE"))
              and key not in {"WOODPECKER_PUBLISH_LEASE", "SSH_ASKPASS"}}
    result.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_TERMINAL_PROMPT="0")
    if auth:
        result.update(GH_TOKEN=os.environ["GH_TOKEN"], GH_HOST="github.com", GH_PROMPT_DISABLED="1")
    return result


def run(*arguments, **kwargs):
    kwargs.setdefault("env", environment())
    return subprocess.run(arguments, check=True, text=True, capture_output=True,
                          timeout=900, **kwargs).stdout.strip()


def api(path):
    return json.loads(run("gh", "api", path, env=environment(auth=True)))


def context():
    if (os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REPOSITORY") != REPOSITORY
            or os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch" or os.environ.get("GITHUB_REF") != "refs/heads/main"
            or os.environ.get("GITHUB_WORKFLOW_REF") != REPOSITORY + "/.github/workflows/docker.yml@refs/heads/main"
            or os.environ.get("GITHUB_ACTOR_ID") != "352757955"):
        raise ValueError("bridge requires the approved App's canonical main dispatch")
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    inputs = event.get("inputs", {})
    sha = inputs.get("source_sha", "")
    digest, config = inputs.get("image_digest", ""), inputs.get("config_digest", "")
    number = inputs.get("pipeline_number", "")
    if (inputs.get("woodpecker_bridge") != "true" or not re.fullmatch(r"[0-9a-f]{40}", sha)
            or sha != os.environ.get("GITHUB_SHA") or not re.fullmatch(r"[1-9][0-9]*", number)
            or any(not re.fullmatch(r"sha256:[0-9a-f]{64}", value) for value in (digest, config))):
        raise ValueError("invalid native handoff identity")
    if run("git", "rev-parse", "HEAD") != sha or run("git", "status", "--porcelain", "--untracked-files=no"):
        raise ValueError("bridge checkout differs from native source")
    if os.environ.get("WOODPECKER_PUBLISHING_ENABLED") != "true":
        raise ValueError("native publication is disabled")
    if api(f"repos/{REPOSITORY}/commits/main")["sha"] != sha:
        raise ValueError("native candidate was superseded on main")
    return {"repository": REPOSITORY, "commit": sha, "image": IMAGE,
            "digest": digest, "configDigest": config,
            "builder": f"https://woodpecker.bolens.dev/repos/11/pipeline/{number}",
            "candidate": f"candidate-{sha}-{number}"}


def candidate_identity(record):
    digest = record["digest"]
    remote = json.loads(run("skopeo", "inspect", f"docker://{IMAGE}:{record['candidate']}"))
    if remote.get("Digest") != digest:
        raise ValueError("candidate tag differs from the dispatched immutable digest")
    manifest = json.loads(run("skopeo", "inspect", "--raw", f"docker://{IMAGE}@{digest}"))
    if manifest.get("config", {}).get("digest") != record["configDigest"]:
        raise ValueError("candidate config differs from native scanned bytes")
    image = json.loads(run("docker", "image", "inspect", f"{IMAGE}@{digest}"))[0]
    labels = image["Config"].get("Labels") or {}
    if (image["Id"] != record["configDigest"] or image["Os"] != "linux" or image["Architecture"] != "amd64"
            or image["Config"].get("User") != "10001:10001"
            or labels.get("org.opencontainers.image.revision") != record["commit"]
            or labels.get("org.opencontainers.image.source") != "https://github.com/" + REPOSITORY):
        raise ValueError("candidate runtime/source/platform differs from native receipt")


def verify():
    record = context()
    wait_for_native_success(api, REPOSITORY, record["commit"], record["builder"], 11, WORKFLOWS, "push")
    run("docker", "pull", f"{IMAGE}@{record['digest']}")
    candidate_identity(record)
    # This invokes all existing UID, read-only source, codecs, decoded PCM and
    # filename/runtime assertions against the pulled digest, without rebuilding.
    run("python3", "scripts/test-docker.py", "--image", f"{IMAGE}@{record['digest']}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "verified.json").write_text(json.dumps(record, indent=2) + "\n")


def inspect_alias(alias):
    result = subprocess.run(["skopeo", "inspect", f"docker://{IMAGE}:{alias}"],
                            check=False, text=True, capture_output=True, timeout=180, env=environment())
    if result.returncode:
        if "manifest unknown" in result.stderr.lower() or "name unknown" in result.stderr.lower():
            return None
        raise ValueError("cannot establish registry alias state")
    return json.loads(result.stdout)["Digest"]


def promote():
    record = context()
    if json.loads((OUTPUT / "verified.json").read_text()) != record:
        raise ValueError("runtime acceptance belongs to another candidate")
    candidate_identity(record)
    version = "sha-" + record["commit"]
    prior = inspect_alias(version)
    if prior is not None and prior != record["digest"]:
        raise ValueError("immutable commit tag already refers to different bytes")
    for alias in ([version] if prior is None else []) + ["latest"]:
        # Current main must still be this source before each mutable registry write.
        if api(f"repos/{REPOSITORY}/commits/main")["sha"] != record["commit"]:
            raise ValueError("candidate was superseded before alias promotion")
        run("docker", "buildx", "imagetools", "create", "--prefer-index=false", "--tag", f"{IMAGE}:{alias}", f"{IMAGE}@{record['digest']}")
        if inspect_alias(alias) != record["digest"]:
            raise ValueError("alias did not preserve the accepted digest")
    (OUTPUT / "published.json").write_text(json.dumps({**record, "status": "accepted-and-promoted"}, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["verify", "promote"])
    args = parser.parse_args()
    {"verify": verify, "promote": promote}[args.phase]()


if __name__ == "__main__":
    main()
