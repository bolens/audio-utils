#!/usr/bin/env python3
"""Offline contract tests use only disposable Git/filesystem state and fake APIs."""

import base64
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import struct
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "offline_environment", ROOT / "scripts/ci/offline_environment.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
CLI_STORE = "/nix/store/" + "a" * 32 + "-devenv"
CLI = CLI_STORE + "/bin/devenv"
NAR = "sha256-" + base64.b64encode(b"x" * 32).decode()
REVISION = "1" * 40
TREE = "2" * 40
IMAGE = "sha256:" + "3" * 64


def namespace_fixture(tunnel=False):
    links = [
        dict(
            index=1,
            name="lo",
            hardware=772,
            flags=0x49,
            kind=b"",
            tunnel={},
            master=b"\0" * 4,
        )
    ]
    if tunnel:
        links.append(
            dict(
                index=2,
                name="tunl0",
                hardware=768,
                flags=128,
                kind=b"ipip",
                tunnel={1: b"\0" * 4, 2: b"\0" * 4, 3: b"\0" * 4},
                master=b"\0" * 4,
            )
        )
    return dict(
        links=links,
        addresses=[(1, 2), (1, 10)],
        routes=[(1, 2, 2, False), (1, 10, 2, False)],
        capabilities=dict.fromkeys(
            ("CapEff", "CapPrm", "CapInh", "CapAmb", "CapBnd"), 0
        ),
    )


class OfflineEnvironmentTests(unittest.TestCase):
    def test_nix_profile_git_resolved_before_child_path_sanitization(self):
        expected = self.identity()
        binary = shutil.which("git")
        self.assertIsNotNone(binary)
        tools = Path(self.temporary.name) / "profile-bin"
        tools.mkdir()
        wrapper = tools / "git"
        # This fixture path is controlled; no caller Git/config state is copied.
        wrapper.write_text('#!/bin/sh\nexec "' + binary + '" "$@"\n')
        wrapper.chmod(0o755)
        with patch.dict(os.environ, {"PATH": str(tools)}):
            self.assertEqual(self.identity(), expected)

    def test_recipe_configuration_is_literal_and_limits_precede_fetch(self):
        recipe = (ROOT / "ci/offline-environment/Dockerfile").read_text()
        bootstrap = (ROOT / "ci/offline-environment/bootstrap.sh").read_text()
        realize = (ROOT / "ci/offline-environment/realize.sh").read_text()
        prepare = (ROOT / "ci/offline-environment/prepare.sh").read_text()
        self.assertNotIn("NIX_CONFIG=", recipe)
        self.assertIn(
            "export NIX_CONFIG='experimental-features = nix-command flakes\nsandbox = false\n",
            bootstrap,
        )
        self.assertIn("cpu_quota == 2 * cpu_period", bootstrap)
        self.assertIn("$memory_max == 4294967296 && $swap_max == 0", bootstrap)
        self.assertLess(
            realize.index("bootstrap.sh realize"), realize.index("nix --version")
        )
        self.assertIn("bootstrap.sh manifest", prepare)
        self.assertNotIn("nix build", prepare)
        self.assertNotIn("nix flake", prepare)
        self.assertNotIn(
            "/bin/devenv", prepare.replace("--cli /opt/audio-ci/devenv/bin/devenv", "")
        )
        self.assertIn(
            "/opt/audio-ci/python scripts/ci/offline_environment.py prepare", prepare
        )
        self.assertIn('ENTRYPOINT ["/opt/audio-ci/python",', recipe)
        first = recipe.split("RUN bash ci/offline-environment/realize.sh", 1)[0]
        self.assertNotIn("source-identity.json", first)
        self.assertNotIn("COPY . ", first)
        self.assertNotIn("offline_environment.py", first)
        for changed in [
            recipe.replace("COPY devenv.nix", "COPY source-identity.json devenv.nix"),
            recipe.replace("RUN bash ci/offline-environment/realize.sh", "RUN true"),
            recipe.replace("RUN --network=none bash", "RUN bash"),
        ]:
            self.put("ci/offline-environment/Dockerfile", changed)
            with self.assertRaises(ValueError):
                self.identity()
        self.put("ci/offline-environment/Dockerfile", recipe)

    def test_late_refusal_reports_only_static_reasons_and_phase(self):
        with patch.object(MODULE, "PREPARATION_PHASE", "store-inventory"):
            actual = MODULE.refusal_report(ValueError("invalid closure path/hash"))
            self.assertEqual(actual["phase"], "store-inventory")
            self.assertEqual(actual["reason"], "invalid closure path/hash")
            for error in [ValueError("PRIVATE_SENTINEL"), OSError("PRIVATE_SENTINEL")]:
                report = MODULE.refusal_report(error)
                self.assertEqual(report["reason"], "unclassified-refusal")
                self.assertNotIn("PRIVATE_SENTINEL", json.dumps(report))
            self.assertFalse(actual["readiness_inferred"])

    def test_cli_source_materialization_is_root_only_and_pinned(self):
        contract = json.loads((self.root / MODULE.CONTRACT).read_text())
        target = Path("/nix/store/" + "c" * 32 + "-source")
        locked = {
            "type": "github",
            "owner": "cachix",
            "repo": "devenv",
            "rev": contract["devenv_revision"],
            "narHash": contract["devenv_source_nar_hash"],
        }
        metadata = {"path": str(target), "locked": locked}
        response = {
            "storePath": str(target),
            "hash": locked["narHash"],
            "locked": locked,
        }

        def path(value):
            if str(value) == "/sys/class/net":
                return SimpleNamespace(
                    iterdir=lambda: iter(
                        [SimpleNamespace(name="lo"), SimpleNamespace(name="eth0")]
                    )
                )
            return Path(value)

        with (
            patch.object(MODULE, "Path", side_effect=path),
            patch.object(MODULE, "network_namespace", return_value=namespace_fixture()),
            patch.object(
                MODULE.subprocess,
                "check_output",
                return_value=json.dumps(response).encode(),
            ) as command,
        ):
            MODULE.materialize_cli_source(contract, target, metadata)
            with patch.object(
                MODULE, "network_namespace", return_value=namespace_fixture(tunnel=True)
            ):
                MODULE.materialize_cli_source(contract, target, metadata)
            self.assertEqual(command.call_count, 2)
        args = command.call_args.args[0]
        self.assertEqual(
            args[:6],
            ["nix", "--offline", "flake", "prefetch", "--json", "--no-use-registries"],
        )
        self.assertEqual(args[6:9], ["--option", "flake-registry", ""])
        self.assertTrue(
            args[9].startswith(
                "github:cachix/devenv/" + locked["rev"] + "?narHash=sha256-"
            )
        )
        self.assertTrue(args[9].endswith("%3D"))
        self.assertNotIn("archive", args)
        self.assertNotIn("build", args)
        self.assertEqual(command.call_args.kwargs["timeout"], 180)

    def test_cli_source_metadata_or_prefetch_mismatch_fails_closed(self):
        contract = json.loads((self.root / MODULE.CONTRACT).read_text())
        target = Path("/nix/store/" + "c" * 32 + "-source")
        locked = {
            "type": "github",
            "owner": "cachix",
            "repo": "devenv",
            "rev": contract["devenv_revision"],
            "narHash": contract["devenv_source_nar_hash"],
        }
        metadata = {"path": str(target), "locked": locked}
        response = {
            "storePath": str(target),
            "hash": locked["narHash"],
            "locked": locked,
        }

        wrong_results = [
            [],
            {**response, "storePath": "/nix/store/" + "d" * 32 + "-source"},
            {**response, "hash": NAR},
            {**response, "locked": {**locked, "rev": "0" * 40}},
            {**response, "locked": {**locked, "owner": "foreign"}},
            {**response, "locked": []},
        ]
        for wrong in wrong_results:
            with (
                self.subTest(response=wrong),
                patch.object(
                    MODULE, "network_namespace", return_value=namespace_fixture()
                ),
                patch.object(
                    MODULE.subprocess,
                    "check_output",
                    return_value=json.dumps(wrong).encode(),
                ),
            ):
                with self.assertRaisesRegex(ValueError, "CLI source prefetch mismatch"):
                    MODULE.materialize_cli_source(contract, target, metadata)
        with patch.object(MODULE.subprocess, "check_output") as command:
            with self.assertRaisesRegex(ValueError, "CLI source metadata mismatch"):
                MODULE.materialize_cli_source(
                    contract, target, {**metadata, "locked": {**locked, "narHash": NAR}}
                )
            self.assertEqual(command.call_count, 0)
        external = namespace_fixture(tunnel=True)
        external["links"][1]["name"] = "eth0"
        with (
            patch.object(MODULE, "network_namespace", return_value=external),
            patch.object(MODULE.subprocess, "check_output") as command,
        ):
            with self.assertRaisesRegex(ValueError, "topology"):
                MODULE.materialize_cli_source(contract, target, metadata)
            self.assertEqual(command.call_count, 0)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="audio-offline-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "checkout with spaces"
        self.root.mkdir()
        self.env = {"PATH": os.environ["PATH"], "LANG": "C.UTF-8"}
        self.env.update(
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=os.devnull,
            HOME=str(Path(self.temporary.name) / "home"),
        )
        Path(self.env["HOME"]).mkdir()
        self.command("init", "--quiet")
        self.command("config", "core.hooksPath", os.devnull)
        self.command("config", "commit.gpgsign", "false")
        self.command("config", "user.name", "Offline fixture")
        self.command("config", "user.email", "offline@example.invalid")
        contract = json.loads((ROOT / MODULE.CONTRACT).read_text())
        self.put(MODULE.CONTRACT, json.dumps(contract))
        self.put(
            "devenv.nix",
            '{ pkgs, ... }: { packages = [ pkgs.bash ]; enterTest = "repo-check"; }\n',
        )
        self.put(
            "devenv.yaml", "inputs:\n  devenv:\n    url: github:cachix/devenv/v1.11.2\n"
        )
        self.put(
            "devenv.lock",
            json.dumps(
                {
                    "nodes": {
                        "devenv": {
                            "locked": {
                                "type": "github",
                                "rev": contract["devenv_revision"],
                            }
                        }
                    }
                }
            ),
        )
        self.put("mcp/npm/package.json", '{"private":true}\n')
        sri = "sha512-" + base64.b64encode(b"x" * 64).decode()
        self.put(
            "mcp/npm/package-lock.json",
            json.dumps(
                {
                    "packages": {
                        "": {},
                        "node_modules/example": {
                            "resolved": "https://registry.npmjs.org/example/-/example-1.tgz",
                            "integrity": sri,
                        },
                    }
                }
            ),
        )
        for relative in contract["recipe_inputs"]:
            self.put(relative, (ROOT / relative).read_text())
        self.put(".gitignore", ".devenv*\nnode_modules/\n")
        self.put("Makefile", "check:\n\ttrue\n")
        self.put("scripts/check-development.sh", "make check\nmake test-all\n")
        self.put(
            "tests/functional/current-source.test.sh",
            "test_current_source() { true; }\n",
        )
        self.put("lib/example.sh", "true\n")
        self.command("add", "--", ".")
        self.command("commit", "--quiet", "-m", "fixture")

    def command(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.root), *args],
            env=self.env,
            stderr=subprocess.PIPE,
            timeout=10,
        )

    def put(self, relative, text):
        p = self.root / relative
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def identity(self):
        return MODULE.input_identity(self.root)

    def manifest(self):
        return {
            "schema": 1,
            "state": "prepared-not-proven-offline",
            "identity": self.identity(),
            "cli": CLI,
            "store_paths": {CLI_STORE: {"narHash": NAR}},
            "npm_cache": "/opt/audio-ci/npm-cache",
            "tool_path": CLI_STORE + "/bin",
            "nix_bin": CLI_STORE + "/bin",
            "public_fetcher_rows": {},
            "allowed_source_revisions": ["4" * 40],
        }

    def source_pack_fixture(self, *, known=None, schema="fetcher-cache-v3.sqlite"):
        cache_dir = Path(self.temporary.name) / ("source-caches-" + schema)
        cache_dir.mkdir()
        cache = cache_dir / MODULE.SOURCE_CACHES[schema]
        subprocess.run(
            ["git", "clone", "--bare", "--quiet", str(self.root), str(cache)],
            env=self.env,
            check=True,
            capture_output=True,
        )
        tree = self.command("rev-parse", "HEAD^{tree}").decode().strip()
        rows = [
            [
                "gitRevToTreeHash",
                json.dumps({"rev": REVISION}),
                json.dumps({"treeHash": tree}),
                1,
            ],
            [
                "gitRevToLastModified",
                json.dumps({"rev": REVISION}),
                '{"lastModified":1}',
                1,
            ],
        ]
        binary = shutil.which("git")
        MODULE.cache_git(
            cache,
            "hash-object",
            "-w",
            "--stdin",
            binary=binary,
            input=b"PRIVATE_UNREACHABLE_SENTINEL",
        )
        packs = cache_dir / "packs"
        with patch.object(MODULE, "tree_nar", return_value=NAR):
            records = MODULE.export_source_packs(
                {schema: rows},
                {REVISION: known},
                cache_dir,
                packs,
                binary=binary,
                nix="/unused/nix",
            )
        return (
            cache_dir,
            cache,
            packs / (MODULE.SOURCE_CACHES[schema] + ".pack"),
            records[schema],
            tree,
        )

    def test_closed_source_pack_hydrates_both_cache_formats_without_private_objects(
        self,
    ):
        for schema in MODULE.SOURCE_CACHES:
            with self.subTest(schema=schema):
                cache_dir, cache, pack, record, tree = self.source_pack_fixture(
                    schema=schema
                )
                # An unrelated object is added to the original cache, never exported.
                unrelated = (
                    MODULE.cache_git(
                        cache,
                        "hash-object",
                        "-w",
                        "--stdin",
                        binary=shutil.which("git"),
                        input=b"PRIVATE_UNREACHABLE_SENTINEL",
                    )
                    .decode()
                    .strip()
                )
                replacement = (
                    MODULE.cache_git(
                        cache, "mktree", binary=shutil.which("git"), input=b""
                    )
                    .decode()
                    .strip()
                )
                subprocess.run(
                    ["git", "--git-dir=" + str(cache), "replace", tree, replacement],
                    env=self.env,
                    check=True,
                    capture_output=True,
                )
                census = MODULE.tree_objects(cache, [tree], shutil.which("git"))
                self.assertEqual(
                    MODULE.sha(MODULE.canonical(census)), record["object_census_sha256"]
                )
                dest = cache_dir / "runtime"
                MODULE.hydrate_source_pack(
                    pack, record, dest, binary=shutil.which("git"), nix="/unused/nix"
                )
                self.assertTrue(list((dest / "objects/pack").glob("*.pack")))
                self.assertTrue(list((dest / "objects/pack").glob("*.idx")))
                self.assertEqual(
                    MODULE.cache_git(
                        dest, "cat-file", "-t", tree, binary=shutil.which("git")
                    ).strip(),
                    b"tree",
                )
                with self.assertRaises(subprocess.CalledProcessError):
                    MODULE.cache_git(
                        dest, "cat-file", "-e", unrelated, binary=shutil.which("git")
                    )
                self.assertEqual(
                    record["roots"][0]["nar_binding"], "lock-has-no-narHash"
                )
                self.assertFalse((dest / "objects/info/alternates").exists())
                self.assertFalse(
                    any(path.is_file() for path in (dest / "refs").rglob("*"))
                )

    def test_missing_tree_and_gitlink_are_rejected(self):
        cache_dir, cache, _, _, _ = self.source_pack_fixture()
        with self.assertRaises(subprocess.CalledProcessError):
            MODULE.tree_objects(cache, ["0" * 40], shutil.which("git"))
        with patch.object(MODULE, "OBJECT_LIMIT", 1):
            with self.assertRaisesRegex(ValueError, "exceeds bound"):
                MODULE.tree_objects(
                    cache,
                    [self.command("rev-parse", "HEAD^{tree}").decode().strip()],
                    shutil.which("git"),
                )
        self.command(
            "update-index", "--add", "--cacheinfo", "160000," + REVISION + ",submodule"
        )
        tree = self.command("write-tree").decode().strip()
        with self.assertRaisesRegex(ValueError, "invalid source tree closure"):
            MODULE.tree_objects(self.root, [tree], shutil.which("git"))

    def test_corrupt_pack_and_extra_unreachable_object_fail_before_gate(self):
        cache_dir, cache, pack, record, _ = self.source_pack_fixture()
        data = bytearray(pack.read_bytes())
        data[-1] ^= 1
        pack.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "invalid source pack"):
            MODULE.hydrate_source_pack(
                pack,
                record,
                cache_dir / "corrupt",
                binary=shutil.which("git"),
                nix="/unused/nix",
            )
        # Even a self-consistent pack checksum may not admit extra, unreachable data.
        extra = (
            MODULE.cache_git(
                cache,
                "hash-object",
                "-w",
                "--stdin",
                binary=shutil.which("git"),
                input=b"UNREACHABLE",
            )
            .decode()
            .strip()
        )
        all_ids = [
            row[0]
            for row in MODULE.tree_objects(
                cache, [record["roots"][0]["tree"]], shutil.which("git")
            )
        ] + [extra]
        with pack.open("wb") as stream:
            MODULE.cache_git(
                cache,
                "pack-objects",
                "--stdout",
                "--no-reuse-delta",
                "--no-reuse-object",
                binary=shutil.which("git"),
                input=("\n".join(all_ids) + "\n").encode(),
                stdout=stream,
            )
        record["pack_sha256"] = MODULE.pack_digest(pack)
        record["pack_bytes"] = pack.stat().st_size
        with self.assertRaisesRegex(ValueError, "unreviewed objects"):
            MODULE.hydrate_source_pack(
                pack,
                record,
                cache_dir / "extra",
                binary=shutil.which("git"),
                nix="/unused/nix",
            )

    def test_known_source_nar_is_required_and_not_fabricated_for_missing_lock_hash(
        self,
    ):
        cache_dir, _, pack, record, _ = self.source_pack_fixture(known=NAR)
        with patch.object(
            MODULE,
            "tree_nar",
            return_value="sha256-" + base64.b64encode(b"y" * 32).decode(),
        ):
            with self.assertRaisesRegex(ValueError, "source tree NAR mismatch"):
                MODULE.hydrate_source_pack(
                    pack,
                    record,
                    cache_dir / "wrong-nar",
                    binary=shutil.which("git"),
                    nix="/unused/nix",
                )
        self.assertEqual(record["roots"][0]["locked_nar_hash"], NAR)
        contract = json.loads((self.root / MODULE.CONTRACT).read_text())
        self.put(
            "devenv.lock",
            json.dumps(
                {
                    "nodes": {
                        "contradictory": {
                            "locked": {
                                "type": "github",
                                "rev": contract["devenv_revision"],
                                "narHash": NAR,
                            }
                        }
                    }
                }
            ),
        )
        cli_source = Path(self.temporary.name) / "cli-source"
        cli_source.mkdir()
        (cli_source / "flake.lock").write_text('{"nodes":{}}')
        with self.assertRaisesRegex(ValueError, "source tree NAR mismatch"):
            MODULE.declared_source_nars(self.root, cli_source, contract)

    def test_tree_nar_uses_raw_objects_not_checkout_attributes(self):
        self.put(".gitattributes", "*.txt export-ignore\n*.txt text eol=crlf\n")
        self.put("nested/raw\nname.txt", "unchanged\n")
        self.put("executable", "#!/bin/sh\n")
        (self.root / "executable").chmod(0o755)
        (self.root / "link").symlink_to("nested/raw\nname.txt")
        self.command("add", "--", ".gitattributes", "nested", "executable", "link")
        tree = self.command("write-tree").decode().strip()

        def hash_current(command, **kwargs):
            directory = Path(command[-1])
            self.assertEqual(
                (directory / "nested/raw\nname.txt").read_bytes(), b"unchanged\n"
            )
            self.assertEqual(os.readlink(directory / "link"), "nested/raw\nname.txt")
            self.assertTrue((directory / "executable").stat().st_mode & 0o111)
            return (NAR + "\n").encode()

        with patch.object(MODULE.subprocess, "check_output", side_effect=hash_current):
            self.assertEqual(
                MODULE.tree_nar(self.root, tree, shutil.which("git"), "/unused/nix"),
                NAR,
            )

    def test_key_deterministic_and_not_checkout_path_or_timestamp(self):
        first = self.identity()
        os.utime(self.root / "devenv.nix", (1, 1))
        self.assertEqual(first, self.identity())
        self.assertNotIn(str(self.root), json.dumps(first))

    def test_all_environment_and_dependency_recipe_inputs_change_key(self):
        first = self.identity()["environment_key"]
        for relative in (
            "devenv.nix",
            "devenv.yaml",
            "Makefile",
            "scripts/check-development.sh",
            "ci/offline-environment/prepare.sh",
        ):
            p = self.root / relative
            original = p.read_text()
            p.write_text(original + "\n# declaration changed\n")
            with self.subTest(path=relative):
                self.assertNotEqual(first, self.identity()["environment_key"])
            p.write_text(original)
        for relative in (
            "devenv.lock",
            "mcp/npm/package.json",
            "mcp/npm/package-lock.json",
        ):
            p = self.root / relative
            original = p.read_text()
            d = json.loads(original)
            d["fixture"] = True
            p.write_text(json.dumps(d))
            with self.subTest(path=relative):
                self.assertNotEqual(first, self.identity()["environment_key"])
            p.write_text(original)

    def test_application_and_failing_test_keep_same_environment_key(self):
        first = self.identity()["environment_key"]
        self.put("lib/example.sh", "return 1 # deliberate current-source defect\n")
        self.put(
            "tests/functional/current-source.test.sh",
            'test_current_source() { fail "CURRENT_SOURCE_NEGATIVE"; }\n',
        )
        self.assertEqual(first, self.identity()["environment_key"])
        # Real admission must observe this marker fail in the whole gate; this
        # unit test only proves it cannot be hidden by changing environment keys.

    def test_local_overrides_and_source_symlinks_refused(self):
        for name in MODULE.OVERRIDES:
            self.put(name, "private fixture value")
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.identity()
            (self.root / name).unlink()
        p = self.root / "devenv.nix"
        p.unlink()
        p.symlink_to("/does-not-exist")
        with self.assertRaises(ValueError):
            self.identity()

    def test_imports_extra_modules_and_mutable_pins_refused(self):
        for body in (
            "{ imports = [ ./extra.nix ]; }",
            "builtins.readFile ./secret",
            '{ x = builtins.getEnv "TOKEN"; }',
        ):
            original = (self.root / "devenv.nix").read_text()
            self.put("devenv.nix", body)
            with self.subTest(body=body), self.assertRaises(ValueError):
                self.identity()
            self.put("devenv.nix", original)
        self.put("extra.nix", "{}")
        self.command("add", "--", "extra.nix")
        with self.assertRaises(ValueError):
            self.identity()

    def test_registry_credentials_or_missing_integrity_refused(self):
        p = self.root / "mcp/npm/package-lock.json"
        original = p.read_text()
        for resolved, integrity in [
            ("https://token@registry.npmjs.org/private.tgz", "sha512-x"),
            ("https://other.invalid/file.tgz", "sha512-x"),
            ("https://registry.npmjs.org/file.tgz", "sha512-not-base64"),
        ]:
            self.put(
                "mcp/npm/package-lock.json",
                json.dumps(
                    {
                        "packages": {
                            "node_modules/x": {
                                "resolved": resolved,
                                "integrity": integrity,
                            }
                        }
                    }
                ),
            )
            with self.subTest(resolved=resolved), self.assertRaises(ValueError):
                self.identity()
        p.write_text(original)

    def test_context_only_copies_environment_recipe_not_application_or_git(self):
        out = Path(self.temporary.name) / "context"
        MODULE.prepare_context(self.root, out)
        self.assertTrue((out / "devenv.nix").is_file())
        self.assertFalse((out / ".git").exists())
        self.assertFalse((out / "lib/example.sh").exists())
        self.assertFalse((out / "tests/functional/current-source.test.sh").exists())
        self.assertFalse((out / "scripts/check-development.sh").exists())
        self.assertIn(
            "scripts/check-development.sh",
            MODULE.read_json(out / "source-identity.json")["identity"]["files"],
        )

    def test_context_refuses_dirty_source_and_does_not_overwrite(self):
        self.put("lib/example.sh", "changed")
        with self.assertRaises(ValueError):
            MODULE.prepare_context(self.root, Path(self.temporary.name) / "context")
        out = Path(self.temporary.name) / "existing"
        out.mkdir()
        with self.assertRaises((ValueError, FileExistsError)):
            MODULE.prepare_context(self.root, out)

    def test_git_inventory_ignores_foreign_repository_environment(self):
        baseline = self.identity()
        with patch.dict(
            os.environ,
            {
                "GIT_DIR": "/invalid/caller",
                "GIT_INDEX_FILE": "/invalid/caller-index",
                "GIT_WORK_TREE": "/invalid/caller-tree",
            },
        ):
            self.assertEqual(baseline, self.identity())

    def test_public_fetcher_projection_filters_unrelated_and_rejects_extras(self):
        rev = "4" * 40
        tree = "5" * 40
        row = [
            "gitRevToTreeHash",
            json.dumps({"rev": rev}),
            json.dumps({"treeHash": tree}),
            1,
        ]
        other = ["secret-domain", json.dumps({"token": "DO_NOT_COPY"}), "{}", 1]
        result = MODULE.project_fetcher_rows([row, other], {rev}, set())
        self.assertEqual(len(result), 1)
        self.assertNotIn("DO_NOT_COPY", json.dumps(result))
        bad = [
            "gitRevToTreeHash",
            json.dumps({"rev": rev}),
            json.dumps({"treeHash": tree, "token": "DO_NOT_COPY"}),
            1,
        ]
        with self.assertRaises(ValueError):
            MODULE.project_fetcher_rows([bad], {rev}, set())

    def test_unbound_fetcher_source_path_or_invalid_hash_refused(self):
        rev = "4" * 40
        row = [
            "fetchToStore",
            json.dumps(
                {
                    "fingerprint": rev,
                    "method": "nar",
                    "name": "source",
                    "path": "/",
                    "store": "/nix/store",
                }
            ),
            json.dumps({"storePath": "outside"}),
            1,
        ]
        with self.assertRaises(ValueError):
            MODULE.project_fetcher_rows([row], {rev}, {CLI_STORE})
        for path, record in [
            ("/tmp/escape", {"narHash": NAR}),
            (CLI_STORE, {"narHash": "sha256-wrong"}),
        ]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                MODULE.valid_store_rows({path: record})

    def test_registered_store_inventory_keeps_regular_derivations(self):
        path = self.root / ("a" * 32 + "-environment.drv")
        path.write_text('Derive([],[],[],"x86_64-linux","builder",[],[])\n')
        self.assertFalse(path.is_dir())
        self.assertTrue(MODULE.store_object_exists(path))
        link = self.root / "store-link"
        link.symlink_to(path.name)
        self.assertTrue(MODULE.store_object_exists(link))
        path.unlink()
        self.assertFalse(MODULE.store_object_exists(path))

    def test_closed_namespace_and_private_store_required(self):
        MODULE.validate_runtime_isolation(
            namespace_fixture(), ["/", "/woodpecker"], True
        )
        for mounts, marker in [
            (["/nix"], True),
            (["/nix/var/nix/db"], True),
            (["/"], False),
        ]:
            with self.subTest(mounts=mounts), self.assertRaises(ValueError):
                MODULE.validate_runtime_isolation(namespace_fixture(), mounts, marker)

    def test_inert_kernel_ipip_requires_structural_evidence(self):
        MODULE.validate_network_namespace(namespace_fixture(tunnel=True))
        for field, value in [
            ("name", "eth0"),
            ("hardware", 1),
            ("kind", b"veth"),
            ("flags", 129),
            ("flags", 192),
            ("flags", 65664),
            ("flags", 0),
            ("master", b"\1\0\0\0"),
            ("master", b"\0"),
        ]:
            wrong = namespace_fixture(tunnel=True)
            wrong["links"][1][field] = value
            with (
                self.subTest(field=field, value=value),
                self.assertRaisesRegex(ValueError, "topology"),
            ):
                MODULE.validate_network_namespace(wrong)
        for attribute, value in [
            (1, b"\1\0\0\0"),
            (2, b"\1\0\0\0"),
            (3, b"\1\0\0\0"),
            (19, b"\1"),
            (2, b"\0"),
        ]:
            wrong = namespace_fixture(tunnel=True)
            wrong["links"][1]["tunnel"][attribute] = value
            with (
                self.subTest(attribute=attribute),
                self.assertRaisesRegex(ValueError, "configured"),
            ):
                MODULE.validate_network_namespace(wrong)

    def test_nonloopback_addresses_routes_and_privilege_are_denied(self):
        for index, family in [(2, 2), (2, 10), (55, 2), (1, 55)]:
            wrong = namespace_fixture(tunnel=True)
            wrong["addresses"].append((index, family))
            with (
                self.subTest(address=(index, family)),
                self.assertRaisesRegex(ValueError, "address"),
            ):
                MODULE.validate_network_namespace(wrong)
        for route in [
            (2, 2, 1, False),
            (55, 2, 1, False),
            (0, 2, 1, False),
            (1, 2, 1, True),
            (1, 55, 1, False),
        ]:
            wrong = namespace_fixture(tunnel=True)
            wrong["routes"].append(route)
            with self.subTest(route=route), self.assertRaisesRegex(ValueError, "route"):
                MODULE.validate_network_namespace(wrong)
        for field in namespace_fixture()["capabilities"]:
            for capability in (12, 21):
                wrong = namespace_fixture(tunnel=True)
                wrong["capabilities"][field] = 1 << capability
                with (
                    self.subTest(field=field, capability=capability),
                    self.assertRaisesRegex(ValueError, "capability"),
                ):
                    MODULE.validate_network_namespace(wrong)
        wrong = namespace_fixture()
        del wrong["capabilities"]["CapBnd"]
        with self.assertRaisesRegex(ValueError, "incomplete"):
            MODULE.validate_network_namespace(wrong)

    def test_netlink_dump_rejects_partial_malformed_or_interrupted_results(self):
        def message(kind, body=b"", flags=0, sequence=1):
            return struct.pack("IHHII", 16 + len(body), kind, flags, sequence, 0) + body

        good = message(16, b"link") + message(3, struct.pack("i", 0))
        for data, flags, sender, accepted in [
            (good, 0, (0, 0), True),
            (b"short", 0, (0, 0), False),
            (message(16, flags=0x10), 0, (0, 0), False),
            (message(3, struct.pack("i", -1)), 0, (0, 0), False),
            (message(16, sequence=2), 0, (0, 0), False),
            (message(2, struct.pack("i", -1)), 0, (0, 0), False),
            (good, MODULE.socket.MSG_TRUNC, (0, 0), False),
            (good, 0, (123, 0), False),
        ]:
            fake = MagicMock()
            fake.__enter__.return_value = fake
            fake.recvmsg.return_value = (data, [], flags, sender)
            with (
                self.subTest(data=data),
                patch.object(MODULE.socket, "AF_NETLINK", 16, create=True),
                patch.object(MODULE.socket, "NETLINK_ROUTE", 0, create=True),
                patch.object(MODULE.socket, "socket", return_value=fake),
            ):
                if accepted:
                    self.assertEqual(MODULE.netlink_dump(18, 16, b""), [b"link"])
                else:
                    with self.assertRaisesRegex(ValueError, "incomplete"):
                        MODULE.netlink_dump(18, 16, b"")
        with self.assertRaisesRegex(ValueError, "incomplete"):
            MODULE.netlink_attributes(b"\3\0\1\0")

    def test_kernel_link_address_route_decoder_feeds_closed_namespace_policy(self):
        def attribute(kind, value):
            size = 4 + len(value)
            return struct.pack("HH", size, kind) + value + b"\0" * (-size % 4)

        def link(index, name, hardware, flags, extra=b""):
            return (
                struct.pack("BBHiII", 0, 0, hardware, index, flags, 0)
                + attribute(3, name.encode() + b"\0")
                + extra
            )

        tunnel = b"".join(attribute(kind, b"\0" * 4) for kind in (1, 2, 3))
        info = attribute(1, b"ipip\0") + attribute(2, tunnel)
        links = [
            link(1, "lo", 772, 0x49),
            link(2, "tunl0", 768, 128, attribute(18, info)),
        ]
        addresses = [struct.pack("BBBBI", family, 0, 0, 0, 1) for family in (2, 10)]
        route = struct.pack("BBBBBBBBI", 2, 8, 0, 0, 255, 2, 254, 2, 0) + attribute(
            4, struct.pack("I", 1)
        )
        status = "".join(
            name + ":\t0000000000000000\n"
            for name in namespace_fixture()["capabilities"]
        )
        original_path = MODULE.Path

        def path(value):
            if str(value) == "/proc/self/status":
                return SimpleNamespace(read_text=lambda: status)
            return original_path(value)

        for forwarding in (None, 18, 21, 22):
            encoded_route = route
            if forwarding is not None:
                encoded_route += attribute(forwarding, b"\0" * 4)
            with (
                self.subTest(forwarding=forwarding),
                patch.object(
                    MODULE,
                    "netlink_dump",
                    side_effect=[links, addresses, [encoded_route]],
                ),
                patch.object(MODULE, "Path", side_effect=path),
                patch.object(
                    MODULE.socket,
                    "if_nameindex",
                    return_value=[(1, "lo"), (2, "tunl0")],
                ),
            ):
                actual = MODULE._read_network_namespace()
                self.assertEqual(actual["links"][1]["kind"], b"ipip")
                self.assertEqual(actual["addresses"], [(1, 2), (1, 10)])
                if forwarding is None:
                    MODULE.validate_network_namespace(actual)
                else:
                    with self.assertRaisesRegex(ValueError, "route"):
                        MODULE.validate_network_namespace(actual)

    def test_runtime_refusal_classes_are_static_and_redacted(self):
        for reason, category in MODULE.RUNTIME_REFUSAL_CLASSES.items():
            result = MODULE.refusal_report(ValueError(reason))
            self.assertEqual(result["reason"], reason)
            self.assertEqual(result["guard_class"], category)
        result = MODULE.refusal_report(ValueError("PRIVATE_SENTINEL"))
        self.assertEqual(result["reason"], "unclassified-refusal")
        self.assertNotIn("PRIVATE_SENTINEL", json.dumps(result))
        with patch.object(
            MODULE, "_read_network_namespace", side_effect=OSError("PRIVATE_SENTINEL")
        ):
            with self.assertRaisesRegex(
                ValueError, "^incomplete network namespace census$"
            ):
                MODULE.network_namespace()

    def test_manifest_drift_fails_before_test_execution(self):
        manifest = self.manifest()
        self.put("devenv.yaml", (self.root / "devenv.yaml").read_text() + "# changed\n")
        actual = self.identity()
        with (
            patch.object(MODULE, "input_identity", return_value=actual) as identity,
            patch.object(Path, "is_dir", return_value=True),
            patch.object(Path, "is_file", return_value=True),
            patch.object(MODULE.subprocess, "run") as run,
        ):
            with self.assertRaisesRegex(
                ValueError, "environment input/recipe key mismatch"
            ):
                MODULE.check_manifest(self.root, manifest)
            identity.assert_called_once()
            self.assertEqual(run.call_count, 0)

    def test_untracked_and_ignored_dependency_declarations_refused(self):
        for path in (
            "util/untracked/Makefile",
            "scripts/new-installer.sh",
            "new-module.nix",
        ):
            self.put(path, "# new dependency declaration\n")
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.identity()
            (self.root / path).unlink()
        self.put(".git/info/exclude", "scripts/private-installer.sh\n")
        self.put(
            "scripts/private-installer.sh", "# ignored new dependency declaration\n"
        )
        with self.assertRaises(ValueError):
            self.identity()

    def test_generated_npm_state_and_ci_consumer_do_not_change_key(self):
        first = self.identity()["environment_key"]
        self.put("mcp/npm/node_modules/example/Makefile", "generated dependency file\n")
        self.put(".woodpecker/woodpecker.yml", "image: example@sha256:new\n")
        self.put(".github/workflows/ci.yml", "image: example@sha256:new\n")
        self.command(
            "add", "--", ".woodpecker/woodpecker.yml", ".github/workflows/ci.yml"
        )
        self.assertEqual(first, self.identity()["environment_key"])

    def test_public_runner_never_bypasses_full_manifest_key(self):
        with (
            patch.object(
                MODULE, "check_manifest", side_effect=ValueError("key mismatch")
            ),
            patch.object(MODULE, "_run_checked_gate") as execute,
        ):
            with self.assertRaisesRegex(ValueError, "key mismatch"):
                MODULE.run_gate(self.root, self.manifest())
        execute.assert_not_called()

    def test_unsupported_runtime_platform_refuses_before_namespace_or_execution(self):
        manifest = self.manifest()
        for system, machine in (("Darwin", "arm64"), ("Linux", "aarch64")):
            with (
                self.subTest(system=system, machine=machine),
                patch.object(MODULE.platform, "system", return_value=system),
                patch.object(MODULE.platform, "machine", return_value=machine),
                patch.object(MODULE, "network_namespace") as census,
                patch.object(
                    MODULE,
                    "Path",
                    side_effect=AssertionError("unexpected namespace read"),
                ),
                patch.object(MODULE.subprocess, "run") as execute,
            ):
                with self.assertRaisesRegex(ValueError, "^wrong execution platform$"):
                    MODULE._run_checked_gate(self.root, manifest, manifest["identity"])
                census.assert_not_called()
                execute.assert_not_called()

    def test_runtime_environment_drops_all_make_and_filter_controls(self):
        manifest = self.manifest()
        identity = manifest["identity"]
        captured = {}
        namespace_paths = {
            "/sys/class/net": SimpleNamespace(
                iterdir=lambda: iter(
                    [SimpleNamespace(name="lo"), SimpleNamespace(name="eth0")]
                )
            ),
            "/proc/self/mountinfo": SimpleNamespace(
                read_text=lambda: "11 0 0:1 / / rw - overlay overlay rw\n"
            ),
            "/.dockerenv": SimpleNamespace(is_file=lambda: True),
        }
        namespace_reads = set()

        def runtime_path(value):
            name = str(value)
            if name in namespace_paths:
                namespace_reads.add(name)
                return namespace_paths[name]
            # All source fixtures and temporary state use the real filesystem.
            return Path(value)

        def execute(command, **kwargs):
            captured.update(command=command, **kwargs)
            user_config = Path(kwargs["env"]["NPM_CONFIG_USERCONFIG"])
            global_config = Path(kwargs["env"]["NPM_CONFIG_GLOBALCONFIG"])
            self.assertNotEqual(user_config, global_config)
            for config in (user_config, global_config):
                self.assertEqual(config.read_bytes(), b"")
                self.assertFalse(config.is_symlink())
                self.assertEqual(config.stat().st_mode & 0o777, 0o600)
                self.assertEqual(config.parent.stat().st_mode & 0o777, 0o700)

            self.assertIn(
                "CURRENT_SOURCE_NEGATIVE",
                (self.root / "tests/functional/current-source.test.sh").read_text(),
            )
            return subprocess.CompletedProcess(command, 1)

        self.put(
            "tests/functional/current-source.test.sh",
            'test_current_source() { fail "CURRENT_SOURCE_NEGATIVE"; }\n',
        )
        inherited = {
            "K": "does-not-exist",
            "AU_TEST_FILTER": "none",
            "AU_SMOKE_ONLY": "none",
            "MAKEFLAGS": "-n",
            "MFLAGS": "-n",
            "GNUMAKEFLAGS": "-n",
            "GH_TOKEN": "PRIVATE_SENTINEL",
            "BASH_ENV": "/bad",
            "PATH": "/bad",
        }
        with (
            patch.dict(os.environ, inherited),
            patch.object(MODULE, "check_manifest", return_value=identity),
            patch.object(MODULE, "prepare_runtime_source_cache") as source_cache,
            patch.object(MODULE, "Path", side_effect=runtime_path),
            patch.object(
                MODULE, "network_namespace", return_value=namespace_fixture()
            ) as interfaces,
            patch.object(MODULE.platform, "system", return_value="Linux") as system,
            patch.object(MODULE.platform, "machine", return_value="x86_64") as machine,
            patch.object(MODULE, "git", return_value=(str(self.root) + "\n").encode()),
            patch.object(MODULE.subprocess, "run", side_effect=execute) as gate,
        ):
            self.assertEqual(MODULE.run_gate(self.root, manifest), 1)
            interfaces.return_value = namespace_fixture(tunnel=True)
            interfaces.return_value["links"][1]["kind"] = b"veth"
            with self.assertRaisesRegex(ValueError, "topology"):
                MODULE.run_gate(self.root, manifest)
            gate.assert_called_once()
            source_cache.assert_called_once()
        self.assertEqual(namespace_reads, set(namespace_paths) - {"/sys/class/net"})
        self.assertEqual(interfaces.call_count, 2)
        self.assertEqual(system.call_count, 2)
        self.assertEqual(machine.call_count, 2)
        self.assertEqual(captured["cwd"], self.root)
        self.assertEqual(
            captured["env"]["PATH"], manifest["tool_path"] + ":" + manifest["nix_bin"]
        )
        self.assertTrue(
            all(name not in captured["env"] for name in inherited if name != "PATH")
        )
        self.assertEqual(captured["env"]["npm_config_offline"], "true")
        self.assertIn("flake-registry =\n", captured["env"]["NIX_CONFIG"])
        self.assertNotIn("channels.nixos.org", captured["env"]["NIX_CONFIG"])
        self.assertEqual(
            captured["command"],
            [CLI, "--verbose", "--max-jobs", "1", "--cores", "2", "--offline", "test"],
        )


if __name__ == "__main__":
    unittest.main()
