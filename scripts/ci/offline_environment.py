#!/usr/bin/env python3
"""Key, prepare, check and execute an offline toolchain; never build/publish on import.
A prepared manifest is NOT readiness. Actual network-none, fresh-state full-gate
Docker observations require independent operator verification.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import resource
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
from urllib.parse import urlencode

CONTRACT = "ci/offline-environment/contract.json"
OVERRIDES = (
    "devenv.local.nix",
    "devenv.local.yaml",
    "secretspec.toml",
    ".env",
    ".npmrc",
    "mcp/npm/.npmrc",
)
STORE = re.compile(r"^/nix/store/[a-z0-9]{32}-[^/\n]+$")
SHA = re.compile(r"^[a-f0-9]{64}$")
REV = re.compile(r"^[a-f0-9]{40}$")
DIGEST = re.compile(r"^sha256:[a-f0-9]{64}$")
FETCH_SCHEMAS = ("fetcher-cache-v3.sqlite", "fetcher-cache-v4.sqlite")
CACHE_DOMAINS = {"gitRevToTreeHash", "gitRevToLastModified", "fetchToStore"}


PREPARATION_PHASE = None
PREPARATION_PHASES = frozenset(
    {
        "context",
        "store-inventory",
        "cli-source-materialization",
        "cli-binding",
        "cli-source-binding",
        "public-fetcher-metadata",
        "public-source-packs",
        "serialize",
    }
)
SAFE_PREPARATION_REASONS = frozenset(
    {
        "invalid closure inventory",
        "invalid closure path/hash",
        "unbound CLI executable",
        "unbound CLI source",
        "unsupported public source cache record",
        "unbound cached source path",
        "unexpected source cache fields",
        "invalid source cache timestamp",
        "invalid public Git tree identity",
        "invalid public Git timestamp",
        "symlink metadata is forbidden",
        "metadata exceeds bound",
        "CLI source metadata mismatch",
        "CLI source prefetch mismatch",
        "CLI source NAR mismatch",
        "CLI source materialization requires network isolation",
        "invalid source tree closure",
        "source tree closure exceeds bound",
        "invalid source pack",
        "source pack contains unreviewed objects",
        "source pack inventory mismatch",
        "invalid source tree NAR",
        "source tree NAR mismatch",
    }
)


def preparation_phase(phase, count=None):
    global PREPARATION_PHASE
    if phase not in PREPARATION_PHASES or (
        count is not None and (type(count) is not int or count < 0)
    ):
        raise ValueError("invalid preparation diagnostic")
    PREPARATION_PHASE = phase
    event = {"phase": phase}
    if count is not None:
        event["count"] = count
    print(
        "offline-environment-prepare " + json.dumps(event, sort_keys=True), flush=True
    )


def refusal_report(error):
    # Only exact hand-authored validation messages may cross the CLI boundary.
    # JSON/OS/subprocess exceptions can include source values and remain redacted.
    reason = (
        str(error)
        if type(error) is ValueError and str(error) in SAFE_PREPARATION_REASONS
        else "unclassified-refusal"
    )
    return {
        "error_type": type(error).__name__,
        "phase": PREPARATION_PHASE,
        "reason": reason,
        "readiness_inferred": False,
    }


def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode()


def sha(value):
    return hashlib.sha256(value).hexdigest()


def read_json(path):
    if path.is_symlink():
        raise ValueError("symlink metadata is forbidden")
    raw = path.read_bytes()
    if len(raw) > 8 * 1024 * 1024:
        raise ValueError("metadata exceeds bound")
    return json.loads(raw)


def source_bytes(root, relative):
    name = PurePosixPath(relative)
    if (
        name.is_absolute()
        or not name.parts
        or any(p in ("..", ".git") for p in name.parts)
    ):
        raise ValueError("unsafe source path")
    current = root
    for part in name.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("source symlink is forbidden")
    if not current.is_file() or current.stat().st_size > 8 * 1024 * 1024:
        raise ValueError("missing/oversized source input")
    return current.read_bytes()


def git(root, *args, binary="git"):
    # Resolve using the caller's fixed tool profile before isolating Git config.
    if binary == "git":
        binary = shutil.which("git")
        if binary is None:
            raise ValueError("git is absent from the declared tool PATH")
    env = {
        "PATH": "/usr/bin:/bin",
        "HOME": "/nonexistent",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
    }
    return subprocess.check_output(
        [
            binary,
            "-c",
            "core.fsmonitor=false",
            "-c",
            f"safe.directory={root}",
            "-C",
            str(root),
            *args,
        ],
        env=env,
        timeout=30,
    )


def validate_contract(contract):
    if contract["nix_version"] != "2.35.4":
        raise ValueError("wrong Nix base version")
    if contract["schema"] != 1 or contract["platform"] != "linux/amd64":
        raise ValueError("unsupported contract")
    if not REV.fullmatch(contract["devenv_revision"]) or not DIGEST.fullmatch(
        contract["nix_base"].split("@")[-1]
    ):
        raise ValueError("mutable environment identity")
    if not re.fullmatch(
        r"sha256-[A-Za-z0-9+/]{43}=", contract.get("devenv_source_nar_hash", "")
    ):
        raise ValueError("mutable environment identity")
    if (
        contract["devenv_arguments"]
        != ["--verbose", "--max-jobs", "1", "--cores", "2", "--offline", "test"]
        or contract["network_mode"] != "none"
    ):
        raise ValueError("offline gate contract changed")


def validate_inputs(root, contract):
    for path in OVERRIDES:
        if (root / path).exists() or (root / path).is_symlink():
            raise ValueError("local override/credential configuration is forbidden")
    nix = source_bytes(root, "devenv.nix").decode()
    # First contract supports this repository's single local Nix module only.
    # New imports/fetchers require a reviewed import census, not a guessed key.
    if re.search(
        r"\b(import|fetchTarball|fetchGit|getFlake|readFile|readDir|getEnv|pathExists)\b|\.\./|\./",
        nix,
    ):
        raise ValueError("unresolved local/dynamic Nix dependency")
    yaml = source_bytes(root, "devenv.yaml").decode().lower()
    if any(
        token in yaml for token in ("imports", "path:", "devenv.local", "secretspec")
    ):
        raise ValueError("unresolved YAML import/override")
    lock = json.loads(source_bytes(root, "devenv.lock"))
    if lock["nodes"]["devenv"]["locked"]["rev"] != contract["devenv_revision"]:
        raise ValueError("devenv CLI and module pins differ")
    for node in lock["nodes"].values():
        if "locked" in node and (
            node["locked"].get("type") != "github"
            or not REV.fullmatch(node["locked"].get("rev", ""))
        ):
            raise ValueError("unsupported/unlocked input")
    npm = json.loads(source_bytes(root, "mcp/npm/package-lock.json"))
    for path, package in npm["packages"].items():
        if not path:
            continue
        resolved = package.get("resolved", "")
        if (
            not resolved.startswith("https://registry.npmjs.org/")
            or "@" in resolved.split("/")[2]
            or not re.fullmatch(
                r"sha512-[A-Za-z0-9+/]{86}==", package.get("integrity", "")
            )
        ):
            raise ValueError("dependency lacks public registry integrity")


def validate_recipe(root, contract):
    recipe = source_bytes(root, "ci/offline-environment/Dockerfile").decode()
    bases = re.findall(r"^ARG NIX_BASE=(.+)$", recipe, re.M)
    if bases != [contract["nix_base"]] or re.findall(r"^FROM (.+)$", recipe, re.M) != [
        "${NIX_BASE} AS prepare",
        "${NIX_BASE}",
    ]:
        raise ValueError("Docker base recipe drift")
    if re.findall(r"^RUN (.+)$", recipe, re.M) != [
        "bash ci/offline-environment/realize.sh",
        "--network=none bash ci/offline-environment/prepare.sh",
    ]:
        raise ValueError("Docker preparation phase drift")
    first = recipe.split("RUN bash ci/offline-environment/realize.sh", 1)[0]
    expected = [
        "devenv.nix devenv.yaml devenv.lock .gitignore /opt/audio-ci-input/",
        "mcp/npm/package.json mcp/npm/package-lock.json /opt/audio-ci-input/mcp/npm/",
        "ci/offline-environment/bootstrap.sh ci/offline-environment/realize.sh /opt/audio-ci-input/ci/offline-environment/",
    ]
    if re.findall(r"^COPY (.+)$", first, re.M) != expected:
        raise ValueError("Docker stable dependency copy boundary drift")
    pins = re.findall(r"AUDIO_CI_DEVENV_REV=([a-f0-9]{40})", recipe)
    if pins != [contract["devenv_revision"]]:
        raise ValueError("Docker CLI recipe drift")


def input_identity(root, git_binary="git"):
    root = root.resolve()
    contract = json.loads(source_bytes(root, CONTRACT))
    validate_contract(contract)
    validate_inputs(root, contract)
    validate_recipe(root, contract)
    tracked = [
        os.fsdecode(p)
        for p in git(root, "ls-files", "-z", binary=git_binary).split(b"\0")
        if p
    ]
    untracked = [
        os.fsdecode(p)
        for p in git(root, "ls-files", "--others", "-z", binary=git_binary).split(b"\0")
        if p
    ]
    known = (
        set(contract["environment_inputs"])
        | set(contract["recipe_inputs"])
        | set(contract["preparation_inputs"])
        | {CONTRACT}
    )
    for path in untracked:
        if path.startswith(("mcp/npm/node_modules/", "tests/.cache/")) or PurePosixPath(
            path
        ).parts[0].startswith(".devenv"):
            continue
        if path not in known and (
            path.endswith(".nix")
            or any(
                fnmatch.fnmatchcase(path, p)
                for p in contract["dependency_declarations"]
            )
        ):
            raise ValueError("untracked dependency declaration is forbidden")
    selected = (
        set(contract["environment_inputs"])
        | set(contract["recipe_inputs"])
        | set(contract["preparation_inputs"])
        | {CONTRACT}
    )
    selected.update(
        p
        for p in tracked
        if any(
            fnmatch.fnmatchcase(p, pattern)
            for pattern in contract["dependency_declarations"]
        )
    )
    if any(p.endswith(".nix") and p != "devenv.nix" for p in tracked):
        raise ValueError("new local Nix module requires an import census")
    files = {path: sha(source_bytes(root, path)) for path in sorted(selected)}
    payload = {"schema": 1, "contract": contract, "files": files}
    return {"environment_key": sha(canonical(payload)), **payload}


def prepare_context(root, destination):
    root = root.resolve()
    identity = input_identity(root)
    if git(root, "status", "--porcelain").strip():
        raise ValueError("context requires a committed clean public checkout")
    revision = git(root, "rev-parse", "HEAD").decode().strip()
    tree = git(root, "rev-parse", "HEAD^{tree}").decode().strip()
    for relative in identity["files"]:
        git(root, "ls-files", "--error-unmatch", "--", relative)
    destination.mkdir(mode=0o700, parents=False, exist_ok=False)
    # Hash gate/dependency declarations, but never bake those application/gate
    # bodies into the environment. Runtime executes the current checkout only.
    copied = (
        set(identity["contract"]["environment_inputs"])
        | set(identity["contract"]["recipe_inputs"])
        | set(identity["contract"]["preparation_inputs"])
        | {CONTRACT}
    )
    for relative in sorted(copied):
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source_bytes(root, relative))
    (destination / "source-identity.json").write_bytes(
        canonical({"revision": revision, "tree": tree, "identity": identity}) + b"\n"
    )
    return {
        "source_revision": revision,
        "source_tree": tree,
        "environment_key": identity["environment_key"],
    }


def valid_store_rows(rows):
    if not isinstance(rows, dict) or not rows or len(rows) > 10000:
        raise ValueError("invalid closure inventory")
    for path, record in rows.items():
        if not STORE.fullmatch(path) or not re.fullmatch(
            r"sha256-[A-Za-z0-9+/]{43}=", record.get("narHash", "")
        ):
            raise ValueError("invalid closure path/hash")


def project_fetcher_rows(rows, revisions, store_paths):
    selected = []
    for domain, key, value, timestamp in rows:
        if domain not in CACHE_DOMAINS:
            continue
        k, v = json.loads(key), json.loads(value)
        revision = k.get("rev") if domain != "fetchToStore" else k.get("fingerprint")
        if revision not in revisions:
            continue
        if domain == "fetchToStore":
            if (
                set(k) - {"fingerprint", "method", "name", "path", "store"}
                or k.get("method") != "nar"
                or k.get("store") != "/nix/store"
                or k.get("path") != "/"
                or k.get("name") != "source"
            ):
                raise ValueError("unsupported public source cache record")
            if (
                set(v) != {"storePath"}
                or "/nix/store/" + v["storePath"] not in store_paths
            ):
                raise ValueError("unbound cached source path")
        elif set(k) != {"rev"} or set(v) != (
            {"treeHash"} if domain == "gitRevToTreeHash" else {"lastModified"}
        ):
            raise ValueError("unexpected source cache fields")
        if type(timestamp) is not int or timestamp < 0:
            raise ValueError("invalid source cache timestamp")
        if domain == "gitRevToTreeHash" and not REV.fullmatch(v["treeHash"]):
            raise ValueError("invalid public Git tree identity")
        if domain == "gitRevToLastModified" and (
            type(v["lastModified"]) is not int or v["lastModified"] < 0
        ):
            raise ValueError("invalid public Git timestamp")
        selected.append(
            [domain, canonical(k).decode(), canonical(v).decode(), timestamp]
        )
    return selected


# GitHub archive fetchers require tree objects as well as SQLite mappings.
SOURCE_CACHES = {
    "fetcher-cache-v3.sqlite": "tarball-cache",
    "fetcher-cache-v4.sqlite": "tarball-cache-v2",
}
OBJECT_LIMIT = 200000
SOURCE_BYTES_LIMIT = 512 * 1024 * 1024


def cache_git(repository, *arguments, binary, input=None, stdin=None, stdout=None):
    # Never consult preparation/developer Git config, hooks, templates or alternates.
    env = {
        "PATH": "/usr/bin:/bin",
        "HOME": "/nonexistent",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_OPTIONAL_LOCKS": "0",
    }

    def limit_output_files():
        resource.setrlimit(
            resource.RLIMIT_FSIZE, (SOURCE_BYTES_LIMIT, SOURCE_BYTES_LIMIT)
        )

    result = subprocess.run(
        [
            binary,
            "-c",
            "core.hooksPath=/dev/null",
            "-c",
            "core.fsmonitor=false",
            "-c",
            "protocol.allow=never",
            "-C",
            str(repository),
            *arguments,
        ],
        input=input,
        stdin=stdin,
        stdout=stdout if stdout is not None else subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        timeout=600,
        check=True,
        preexec_fn=limit_output_files,
    )
    return result.stdout


def tree_objects(repository, roots, binary, *, all_objects=False):
    if not roots or len(roots) > 32 or any(not REV.fullmatch(t) for t in roots):
        raise ValueError("invalid source tree closure")
    for tree in roots:
        if (
            cache_git(repository, "cat-file", "-t", tree, binary=binary).strip()
            != b"tree"
        ):
            raise ValueError("invalid source tree closure")
        # Gitlinks have no archive-backed source payload and are never admitted.
        entries = cache_git(repository, "ls-tree", "-rz", tree, binary=binary)
        for row in entries.split(b"\0"):
            if row and row.split(b"\t", 1)[0].split()[0] not in (
                b"100644",
                b"100755",
                b"120000",
            ):
                raise ValueError("invalid source tree closure")
    if all_objects:
        raw = cache_git(
            repository,
            "cat-file",
            "--batch-all-objects",
            "--batch-check=%(objectname) %(objecttype) %(objectsize)",
            binary=binary,
        )
    else:
        objects = cache_git(
            repository,
            "rev-list",
            "--objects",
            "--no-object-names",
            *roots,
            binary=binary,
        )
        if len(objects.splitlines()) > OBJECT_LIMIT:
            raise ValueError("source tree closure exceeds bound")
        raw = cache_git(
            repository,
            "cat-file",
            "--batch-check=%(objectname) %(objecttype) %(objectsize)",
            binary=binary,
            input=objects,
        )
    rows = []
    for line in raw.decode("ascii").splitlines():
        oid, kind, size = line.split()
        if (
            not REV.fullmatch(oid)
            or kind not in ("tree", "blob")
            or not size.isdecimal()
        ):
            raise ValueError("invalid source tree closure")
        rows.append((oid, kind, int(size)))
    if (
        not rows
        or len(rows) > OBJECT_LIMIT
        or len({r[0] for r in rows}) != len(rows)
        or sum(r[2] for r in rows) > SOURCE_BYTES_LIMIT
    ):
        raise ValueError("source tree closure exceeds bound")
    return sorted(rows)


def pack_digest(path):
    if (
        path.is_symlink()
        or not path.is_file()
        or not 0 < path.stat().st_size <= SOURCE_BYTES_LIMIT
    ):
        raise ValueError("invalid source pack")
    value = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            value.update(chunk)
    return value.hexdigest()


def tree_nar(repository, tree, binary, nix):
    with tempfile.TemporaryDirectory(prefix="audio-public-tree-") as temporary:
        destination = Path(temporary) / "source"
        destination.mkdir()
        # Read raw blobs in one bounded batch, never checkout/archive attributes.
        raw = cache_git(repository, "ls-tree", "-rtz", tree, binary=binary)
        entries = [row.split(b"\t", 1) for row in raw.split(b"\0") if row]
        if len(entries) > OBJECT_LIMIT:
            raise ValueError("source tree closure exceeds bound")
        blob_ids = [
            header.decode("ascii").split()[2]
            for header, _ in entries
            if header.decode("ascii").split()[1] == "blob"
        ]
        batch = Path(temporary) / "objects.batch"
        with batch.open("xb") as stream:
            cache_git(
                repository,
                "cat-file",
                "--batch",
                binary=binary,
                input=("\n".join(blob_ids) + "\n").encode() if blob_ids else b"",
                stdout=stream,
            )
        seen, copied = set(), 0
        with batch.open("rb") as stream:
            for header, raw_name in entries:
                mode, kind, oid = header.decode("ascii").split()
                name = PurePosixPath(os.fsdecode(raw_name))
                if (
                    name.is_absolute()
                    or not name.parts
                    or any(part in ("..", ".", ".git") for part in name.parts)
                    or name in seen
                ):
                    raise ValueError("invalid source tree closure")
                seen.add(name)
                target = destination
                for component in name.parts[:-1]:
                    target = target / component
                    if not target.is_dir() or target.is_symlink():
                        raise ValueError("invalid source tree closure")
                target = target / name.name
                if mode == "040000" and kind == "tree":
                    target.mkdir()
                    continue
                if mode not in ("100644", "100755", "120000") or kind != "blob":
                    raise ValueError("invalid source tree closure")
                actual = stream.readline(128).decode("ascii").split()
                if (
                    len(actual) != 3
                    or actual[:2] != [oid, "blob"]
                    or not actual[2].isdecimal()
                ):
                    raise ValueError("invalid source tree closure")
                size = int(actual[2])
                copied += size
                if copied > SOURCE_BYTES_LIMIT:
                    raise ValueError("source tree closure exceeds bound")
                if mode == "120000":
                    content = stream.read(size)
                    if len(content) != size:
                        raise ValueError("invalid source tree closure")
                    target.symlink_to(os.fsdecode(content))
                else:
                    with target.open("xb") as output:
                        remaining = size
                        while remaining:
                            chunk = stream.read(min(remaining, 1024 * 1024))
                            if not chunk:
                                raise ValueError("invalid source tree closure")
                            output.write(chunk)
                            remaining -= len(chunk)
                    target.chmod(0o755 if mode == "100755" else 0o644)
                if stream.read(1) != b"\n":
                    raise ValueError("invalid source tree closure")
            if stream.read(1):
                raise ValueError("invalid source tree closure")
        value = (
            subprocess.check_output(
                [
                    nix,
                    "--offline",
                    "--extra-experimental-features",
                    "nix-command",
                    "--option",
                    "flake-registry",
                    "",
                    "hash",
                    "path",
                    "--mode",
                    "nar",
                    "--type",
                    "sha256",
                    "--sri",
                    str(destination),
                ],
                env={"PATH": "/usr/bin:/bin", "HOME": temporary, "NIX_REMOTE": "local"},
                stderr=subprocess.PIPE,
                timeout=600,
            )
            .decode()
            .strip()
        )
        if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", value):
            raise ValueError("invalid source tree NAR")
        return value


def hydrate_source_pack(pack, record, destination, *, binary, nix):
    if set(record) != {
        "pack_sha256",
        "pack_bytes",
        "roots",
        "objects",
        "object_types",
        "object_bytes",
        "object_census_sha256",
    }:
        raise ValueError("invalid source pack")
    if (
        pack_digest(pack) != record["pack_sha256"]
        or pack.stat().st_size != record["pack_bytes"]
    ):
        raise ValueError("invalid source pack")
    if not record["roots"] or len(record["roots"]) > 32:
        raise ValueError("invalid source tree closure")
    roots = sorted({row["tree"] for row in record["roots"]})
    destination.mkdir(mode=0o700)  # Fresh per-job COW cache only; never reuse a repo.
    cache_git(
        destination,
        "init",
        "--bare",
        "--object-format=sha1",
        "--template=",
        ".",
        binary=binary,
    )
    with pack.open("rb") as stream:
        cache_git(
            destination,
            "index-pack",
            "--stdin",
            "--strict",
            "--max-input-size=" + str(SOURCE_BYTES_LIMIT),
            binary=binary,
            stdin=stream,
        )
    objects = tree_objects(destination, roots, binary)
    if objects != tree_objects(destination, roots, binary, all_objects=True):
        raise ValueError("source pack contains unreviewed objects")
    actual = {
        "objects": len(objects),
        "object_types": {
            kind: sum(r[1] == kind for r in objects) for kind in ("tree", "blob")
        },
        "object_bytes": sum(r[2] for r in objects),
        "object_census_sha256": sha(canonical(objects)),
    }
    if any(record[k] != v for k, v in actual.items()):
        raise ValueError("source pack inventory mismatch")
    for row in record["roots"]:
        if set(row) != {
            "revision",
            "tree",
            "locked_nar_hash",
            "nar_binding",
        } or not REV.fullmatch(row["revision"]):
            raise ValueError("invalid source tree closure")
        known = row["locked_nar_hash"]
        if known is None:
            if row["nar_binding"] != "lock-has-no-narHash":
                raise ValueError("invalid source tree NAR")
        elif (
            row["nar_binding"] != "locked-narHash"
            or tree_nar(destination, row["tree"], binary, nix) != known
        ):
            raise ValueError("source tree NAR mismatch")
    return actual


def export_source_packs(caches, declarations, cache_dir, destination, *, binary, nix):
    destination.mkdir(mode=0o700)
    records = {}
    for schema, rows in caches.items():
        trees, modified = {}, set()
        for domain, key, value, _ in rows:
            key, value = json.loads(key), json.loads(value)
            if domain == "gitRevToTreeHash":
                if key["rev"] in trees:
                    raise ValueError("invalid source tree closure")
                trees[key["rev"]] = value["treeHash"]
            elif domain == "gitRevToLastModified":
                modified.add(key["rev"])
        if not trees or set(trees) != modified or not set(trees) <= set(declarations):
            raise ValueError("invalid source tree closure")
        repository = cache_dir / SOURCE_CACHES[schema]
        if (
            repository.is_symlink()
            or not repository.is_dir()
            or (repository / "objects/info/alternates").exists()
        ):
            raise ValueError("invalid source tree closure")
        objects = tree_objects(repository, sorted(set(trees.values())), binary)
        pack = destination / (SOURCE_CACHES[schema] + ".pack")
        with pack.open("xb") as stream:
            cache_git(
                repository,
                "pack-objects",
                "--stdout",
                "--no-reuse-delta",
                "--no-reuse-object",
                "--window=0",
                "--depth=0",
                binary=binary,
                input=("\n".join(r[0] for r in objects) + "\n").encode(),
                stdout=stream,
            )
        record = {
            "pack_sha256": pack_digest(pack),
            "pack_bytes": pack.stat().st_size,
            "roots": [
                {
                    "revision": revision,
                    "tree": tree,
                    "locked_nar_hash": declarations[revision],
                    "nar_binding": "lock-has-no-narHash"
                    if declarations[revision] is None
                    else "locked-narHash",
                }
                for revision, tree in sorted(trees.items())
            ],
            "objects": len(objects),
            "object_types": {
                kind: sum(r[1] == kind for r in objects) for kind in ("tree", "blob")
            },
            "object_bytes": sum(r[2] for r in objects),
            "object_census_sha256": sha(canonical(objects)),
        }
        with tempfile.TemporaryDirectory(prefix="audio-pack-verify-") as temporary:
            hydrate_source_pack(
                pack, record, Path(temporary) / "cache", binary=binary, nix=nix
            )
        records[schema] = record
    return records


def declared_source_nars(root, cli_source, contract):
    result = {}
    for lock in (
        json.loads(source_bytes(root, "devenv.lock")),
        read_json(cli_source / "flake.lock"),
    ):
        for node in lock["nodes"].values():
            locked = node.get("locked", {})
            revision = locked.get("rev")
            if revision:
                if not REV.fullmatch(revision) or locked.get("type") != "github":
                    raise ValueError("invalid source tree closure")
                known = locked.get("narHash")
                if (
                    known is not None
                    and revision in result
                    and result[revision] not in (None, known)
                ):
                    raise ValueError("source tree NAR mismatch")
                result[revision] = known or result.get(revision)
    if result.get(contract["devenv_revision"]) not in (
        None,
        contract["devenv_source_nar_hash"],
    ):
        raise ValueError("source tree NAR mismatch")
    result[contract["devenv_revision"]] = contract["devenv_source_nar_hash"]
    return result


def materialize_cli_source(contract, cli_source, metadata):
    """Copy only the pinned root tree from Nix's cached virtual source to store."""
    expected = {
        "type": "github",
        "owner": "cachix",
        "repo": "devenv",
        "rev": contract["devenv_revision"],
        "narHash": contract["devenv_source_nar_hash"],
    }
    if (
        not isinstance(metadata, dict)
        or not STORE.fullmatch(str(cli_source))
        or metadata.get("path") != str(cli_source)
        or not isinstance(metadata.get("locked"), dict)
        or any(metadata["locked"].get(key) != value for key, value in expected.items())
    ):
        raise ValueError("CLI source metadata mismatch")
    # BuildKit can retain a sysfs mount tagged to a different network namespace.
    # Enumerate interfaces through a socket in this process's current namespace.
    if {name for _, name in socket.if_nameindex()} != {"lo"}:
        raise ValueError("CLI source materialization requires network isolation")
    reference = (
        "github:cachix/devenv/"
        + contract["devenv_revision"]
        + "?"
        + urlencode({"narHash": expected["narHash"]})
    )
    result = json.loads(
        subprocess.check_output(
            [
                "nix",
                "--offline",
                "flake",
                "prefetch",
                "--json",
                "--no-use-registries",
                "--option",
                "flake-registry",
                "",
                reference,
            ],
            timeout=180,
        )
    )
    if (
        not isinstance(result, dict)
        or result.get("storePath") != str(cli_source)
        or result.get("hash") != expected["narHash"]
    ):
        raise ValueError("CLI source prefetch mismatch")
    locked = result.get("locked")
    if locked is not None and (
        not isinstance(locked, dict)
        or any(
            key in locked and locked[key] != value for key, value in expected.items()
        )
    ):
        raise ValueError("CLI source prefetch mismatch")


def prepare_manifest(root, output, cli, cli_source):
    preparation_phase("context")
    # Only the Dockerfile preparation stage may write this toolchain manifest.
    if (
        os.geteuid() != 0
        or os.environ.get("AUDIO_CI_ENV_PREPARE") != "1"
        or root.resolve() != Path("/opt/audio-ci-input")
        or os.environ.get("NIX_REMOTE") != "local"
    ):
        raise ValueError("not an isolated preparation context")
    mountpoints = [
        line.split()[4]
        for line in Path("/proc/self/mountinfo").read_text().splitlines()
    ]
    if any(m == "/nix" or m.startswith("/nix/") for m in mountpoints):
        raise ValueError("mounted Nix store/database is forbidden")
    source = read_json(root / "source-identity.json")
    identity = source["identity"]
    if identity["environment_key"] != sha(
        canonical({k: identity[k] for k in ("schema", "contract", "files")})
    ):
        raise ValueError("context key mismatch")
    copied = (
        set(identity["contract"]["environment_inputs"])
        | set(identity["contract"]["recipe_inputs"])
        | set(identity["contract"]["preparation_inputs"])
        | {CONTRACT}
    )
    for path in copied:
        if sha(source_bytes(root, path)) != identity["files"][path]:
            raise ValueError("context source changed")
    contract = identity["contract"]
    if (
        os.environ.get("AUDIO_CI_NIX_BASE") != contract["nix_base"]
        or os.environ.get("AUDIO_CI_DEVENV_REV") != contract["devenv_revision"]
    ):
        raise ValueError("builder arguments do not match declared immutable inputs")
    validate_contract(contract)
    validate_inputs(root, contract)
    validate_recipe(root, contract)
    if (
        Path("/tmp/audio-ci-base-nix-version").read_text().strip()
        != "nix (Nix) " + contract["nix_version"]
    ):
        raise ValueError("preparation did not use declared Nix base")
    preparation_phase("cli-source-materialization")
    materialize_cli_source(
        contract, cli_source, read_json(Path("/tmp/audio-ci-cli-source.json"))
    )
    preparation_phase("store-inventory")
    rows = json.loads(
        subprocess.check_output(["nix", "path-info", "--json", "--all"], timeout=60)
    )
    preparation_phase("store-inventory", len(rows))
    if isinstance(rows, list):
        rows = {r["path"]: r for r in rows}
    store_rows = {p: {"narHash": r["narHash"]} for p, r in rows.items()}
    valid_store_rows(store_rows)
    cli = cli.resolve()
    cli_root = str(cli.parent.parent)
    preparation_phase("cli-binding", int(cli_root in store_rows))
    if cli.name != "devenv" or cli_root not in store_rows:
        raise ValueError("unbound CLI executable")
    revisions = {
        node["locked"]["rev"]
        for node in json.loads(source_bytes(root, "devenv.lock"))["nodes"].values()
        if "locked" in node
    }
    revisions.add(contract["devenv_revision"])
    preparation_phase("cli-source-binding", int(str(cli_source) in store_rows))
    if not STORE.fullmatch(str(cli_source)) or str(cli_source) not in store_rows:
        raise ValueError("unbound CLI source")
    if store_rows[str(cli_source)]["narHash"] != contract["devenv_source_nar_hash"]:
        raise ValueError("CLI source NAR mismatch")
    revisions.update(
        n["locked"]["rev"]
        for n in read_json(cli_source / "flake.lock")["nodes"].values()
        if "rev" in n.get("locked", {})
    )
    caches = {}
    preparation_phase("public-fetcher-metadata")
    for name in FETCH_SCHEMAS:
        path = Path.home() / ".cache/nix" / name
        if path.is_file() and not path.is_symlink():
            with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) as db:
                caches[name] = project_fetcher_rows(
                    db.execute(
                        "SELECT domain,key,value,timestamp FROM Cache"
                    ).fetchall(),
                    revisions,
                    store_rows,
                )
    preparation_phase("public-source-packs")
    source_packs = export_source_packs(
        caches,
        declared_source_nars(root, cli_source, contract),
        Path.home() / ".cache/nix",
        Path("/opt/audio-ci/source-cache"),
        binary=shutil.which("git"),
        nix=shutil.which("nix"),
    )
    preparation_phase("serialize", len(store_rows))
    manifest = {
        "schema": 1,
        "state": "prepared-not-proven-offline",
        "identity": identity,
        "source_revision": source["revision"],
        "source_tree": source["tree"],
        "cli": str(cli),
        "python": sys.executable,
        "tool_path": str((root / ".devenv/profile").resolve() / "bin"),
        "nix_bin": str(Path(shutil.which("nix")).resolve().parent),
        "store_paths": store_rows,
        "public_fetcher_rows": caches,
        "source_packs": source_packs,
        "source_cache_cli_root": str(cli_source),
        "allowed_source_revisions": sorted(revisions),
        "npm_cache": "/opt/audio-ci/npm-cache",
    }
    output.write_bytes(canonical(manifest) + b"\n")


def store_object_exists(path):
    # Registered Nix objects include derivation files and symlinks, not only dirs.
    # Content/NAR verification remains an independent admission requirement.
    return path.is_dir() or path.is_file() or path.is_symlink()


def check_manifest(root, manifest):
    if manifest["schema"] != 1 or manifest["state"] != "prepared-not-proven-offline":
        raise ValueError("invalid preparation manifest; no readiness inferred")
    valid_store_rows(manifest["store_paths"])
    profile = Path(manifest["tool_path"])
    if (
        profile.name != "bin"
        or str(profile.parent) not in manifest["store_paths"]
        or not profile.is_dir()
    ):
        raise ValueError("missing/unbound fixed tool profile")
    nix_bin = Path(manifest["nix_bin"])
    if (
        nix_bin.name != "bin"
        or str(nix_bin.parent) not in manifest["store_paths"]
        or not (nix_bin / "nix").is_file()
    ):
        raise ValueError("missing/unbound base Nix binary")
    identity = input_identity(root, git_binary=str(profile / "git"))
    if manifest["identity"] != identity:
        raise ValueError("environment input/recipe key mismatch")
    for path in manifest["store_paths"]:
        if not store_object_exists(Path(path)):
            raise ValueError("missing declared Nix object; no download fallback")
    cli = Path(manifest["cli"])
    if (
        not cli.is_absolute()
        or str(cli.parent.parent) not in manifest["store_paths"]
        or cli.name != "devenv"
        or not cli.is_file()
    ):
        raise ValueError("missing/unbound CLI")
    if (
        manifest["npm_cache"] != "/opt/audio-ci/npm-cache"
        or not Path(manifest["npm_cache"]).is_dir()
    ):
        raise ValueError("missing npm cache")
    return identity


def prepare_runtime_source_cache(root, manifest, cache_dir):
    cli_root = manifest["source_cache_cli_root"]
    contract = manifest["identity"]["contract"]
    if (
        manifest["store_paths"].get(cli_root, {}).get("narHash")
        != contract["devenv_source_nar_hash"]
    ):
        raise ValueError("CLI source NAR mismatch")
    declarations = declared_source_nars(root, Path(cli_root), contract)
    packs = manifest["source_packs"]
    if not packs or set(packs) != set(manifest["public_fetcher_rows"]):
        raise ValueError("invalid source pack")
    for schema, record in packs.items():
        if schema not in SOURCE_CACHES:
            raise ValueError("invalid source pack")
        pairs = sorted(
            (json.loads(key)["rev"], json.loads(value)["treeHash"])
            for domain, key, value, _ in manifest["public_fetcher_rows"][schema]
            if domain == "gitRevToTreeHash"
        )
        if sorted((row["revision"], row["tree"]) for row in record["roots"]) != pairs:
            raise ValueError("invalid source tree closure")
        for row in record["roots"]:
            if (
                row["revision"] not in declarations
                or row["locked_nar_hash"] != declarations[row["revision"]]
            ):
                raise ValueError("source tree NAR mismatch")
        hydrate_source_pack(
            Path("/opt/audio-ci/source-cache") / (SOURCE_CACHES[schema] + ".pack"),
            record,
            cache_dir / SOURCE_CACHES[schema],
            binary=str(Path(manifest["tool_path"]) / "git"),
            nix=str(Path(manifest["nix_bin"]) / "nix"),
        )


def validate_runtime_isolation(interfaces, mountpoints, docker_marker):
    if set(interfaces) != {"lo"} or not docker_marker:
        raise ValueError("network-none disposable Docker runtime required")
    if any(m == "/nix" or m.startswith("/nix/") for m in mountpoints):
        raise ValueError("mounted/shared Nix store or database forbidden")


def run_gate(root, manifest):
    identity = check_manifest(root, manifest)
    return _run_checked_gate(root, manifest, identity)


def _run_checked_gate(root, manifest, identity):
    """Internal execution primitive; normal CLI always validates the full key."""
    validate_runtime_isolation(
        [name for _, name in socket.if_nameindex()],
        [
            line.split()[4]
            for line in Path("/proc/self/mountinfo").read_text().splitlines()
        ],
        Path("/.dockerenv").is_file(),
    )
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("wrong execution platform")
    if git(
        root,
        "rev-parse",
        "--show-toplevel",
        binary=str(Path(manifest["tool_path"]) / "git"),
    ).decode().strip() != str(root):
        raise ValueError("execution root is not this checkout")
    with tempfile.TemporaryDirectory(prefix="audio-ci-state-") as temporary:
        state = Path(temporary)
        env = {
            "PATH": manifest["tool_path"] + ":" + manifest["nix_bin"],
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TZ": "UTC",
        }
        for name in ("home", "cache", "data", "config", "runtime", "tmp"):
            (state / name).mkdir(mode=0o700)
        env.update(
            HOME=str(state / "home"),
            XDG_CACHE_HOME=str(state / "cache"),
            XDG_DATA_HOME=str(state / "data"),
            XDG_CONFIG_HOME=str(state / "config"),
            XDG_RUNTIME_DIR=str(state / "runtime"),
            TMPDIR=str(state / "tmp"),
            CI="true",
            JOBS="2",
            NIX_REMOTE="local",
            NIX_CONFIG="experimental-features = nix-command flakes\nsandbox = false\nbuild-users-group =\nmax-jobs = 1\ncores = 2\nsubstituters =\nflake-registry =\n",
            npm_config_offline="true",
            npm_config_cache=manifest["npm_cache"],
            NPM_CONFIG_USERCONFIG="/dev/null",
            NPM_CONFIG_GLOBALCONFIG="/dev/null",
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="safe.directory",
            GIT_CONFIG_VALUE_0=str(root),
        )
        cache_dir = state / "cache/nix"
        cache_dir.mkdir()
        for name, rows in manifest["public_fetcher_rows"].items():
            if name not in FETCH_SCHEMAS:
                raise ValueError("unexpected cache metadata")
            selected = project_fetcher_rows(
                rows, set(manifest["allowed_source_revisions"]), manifest["store_paths"]
            )
            if selected != rows:
                raise ValueError("unapproved source cache row")
            with sqlite3.connect(cache_dir / name) as db:
                db.execute(
                    "CREATE TABLE Cache(domain TEXT NOT NULL,key TEXT NOT NULL,value TEXT NOT NULL,timestamp INTEGER NOT NULL,PRIMARY KEY(domain,key))"
                )
                db.executemany("INSERT INTO Cache VALUES(?,?,?,?)", rows)
        prepare_runtime_source_cache(root, manifest, cache_dir)
        command = [manifest["cli"], *identity["contract"]["devenv_arguments"]]
        print(
            "offline-environment-gate "
            + json.dumps(
                {
                    "environment_key": identity["environment_key"],
                    "root": str(root),
                    "source_revision": git(
                        root,
                        "rev-parse",
                        "HEAD",
                        binary=str(Path(manifest["tool_path"]) / "git"),
                    )
                    .decode()
                    .strip(),
                    "command": command,
                    "npm_offline": True,
                }
            ),
            flush=True,
        )
        return subprocess.run(command, cwd=root, env=env, check=False).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "operation", choices=("key", "context", "prepare", "check", "run")
    )
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--manifest", type=Path, default=Path("/opt/audio-ci/environment.json")
    )
    parser.add_argument("--cli", type=Path)
    parser.add_argument("--cli-source", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    if args.operation == "key":
        result = input_identity(root)
    elif args.operation == "context":
        if args.output is None:
            parser.error("context requires --output")
        result = prepare_context(root, args.output)
    elif args.operation == "prepare":
        if args.output is None or args.cli is None or args.cli_source is None:
            parser.error("prepare requires --output, --cli and --cli-source")
        prepare_manifest(root, args.output, args.cli, args.cli_source)
        result = {"state": "prepared-not-proven-offline"}
    else:
        manifest = read_json(args.manifest)
        if args.operation == "run":
            return run_gate(root, manifest)
        result = {
            "environment_key": check_manifest(root, manifest)["environment_key"],
            "state": "manifest-valid-not-runtime-proof",
        }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ValueError,
        KeyError,
        OSError,
        subprocess.SubprocessError,
        sqlite3.Error,
    ) as error:
        raise SystemExit(
            "offline environment refused: "
            + json.dumps(refusal_report(error), sort_keys=True)
        ) from None
