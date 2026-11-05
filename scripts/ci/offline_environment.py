#!/usr/bin/env python3
"""Key, prepare, check and execute an offline toolchain; never build/publish on import.
A prepared manifest is NOT readiness. Actual network-none, fresh-state full-gate
Docker observations belong to the independent Root proof controller.
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
import shutil
import sqlite3
import subprocess
import sys
import tempfile

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
    if (
        contract["devenv_arguments"]
        != ["--max-jobs", "1", "--cores", "2", "--offline", "test"]
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


def prepare_manifest(root, output, cli, cli_source):
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
    rows = json.loads(
        subprocess.check_output(["nix", "path-info", "--json", "--all"], timeout=60)
    )
    if isinstance(rows, list):
        rows = {r["path"]: r for r in rows}
    store_rows = {p: {"narHash": r["narHash"]} for p, r in rows.items()}
    valid_store_rows(store_rows)
    cli = cli.resolve()
    cli_root = str(cli.parent.parent)
    if cli.name != "devenv" or cli_root not in store_rows:
        raise ValueError("unbound CLI executable")
    revisions = {
        node["locked"]["rev"]
        for node in json.loads(source_bytes(root, "devenv.lock"))["nodes"].values()
        if "locked" in node
    }
    revisions.add(contract["devenv_revision"])
    if not STORE.fullmatch(str(cli_source)) or str(cli_source) not in store_rows:
        raise ValueError("unbound CLI source")
    revisions.update(
        n["locked"]["rev"]
        for n in read_json(cli_source / "flake.lock")["nodes"].values()
        if "rev" in n.get("locked", {})
    )
    caches = {}
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


def validate_runtime_isolation(interfaces, mountpoints, docker_marker):
    if set(interfaces) != {"lo"} or not docker_marker:
        raise ValueError("network-none disposable Docker runtime required")
    if any(m == "/nix" or m.startswith("/nix/") for m in mountpoints):
        raise ValueError("mounted/shared Nix store or database forbidden")


def run_gate(root, manifest):
    identity = check_manifest(root, manifest)
    validate_runtime_isolation(
        [p.name for p in Path("/sys/class/net").iterdir()],
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
            NIX_CONFIG="experimental-features = nix-command flakes\nsandbox = false\nbuild-users-group =\nmax-jobs = 1\ncores = 2\nsubstituters =\n",
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
            + type(error).__name__
            + "; no readiness inferred"
        ) from None
