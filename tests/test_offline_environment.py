#!/usr/bin/env python3
"""Offline contract tests use only disposable Git/filesystem state and fake APIs."""

import base64
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

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

    def test_loopback_only_and_private_store_required(self):
        MODULE.validate_runtime_isolation(["lo"], ["/", "/woodpecker"], True)
        for interfaces, mounts, marker in [
            (["lo", "eth0"], ["/"], True),
            (["lo"], ["/nix"], True),
            (["lo"], ["/nix/var/nix/db"], True),
            (["lo"], ["/"], False),
        ]:
            with (
                self.subTest(interfaces=interfaces, mounts=mounts),
                self.assertRaises(ValueError),
            ):
                MODULE.validate_runtime_isolation(interfaces, mounts, marker)

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

    def test_runtime_environment_drops_all_make_and_filter_controls(self):
        manifest = self.manifest()
        identity = manifest["identity"]
        captured = {}
        namespace_paths = {
            "/sys/class/net": SimpleNamespace(
                iterdir=lambda: iter([SimpleNamespace(name="lo")])
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
            patch.object(MODULE, "Path", side_effect=runtime_path),
            patch.object(MODULE.platform, "system", return_value="Linux") as system,
            patch.object(MODULE.platform, "machine", return_value="x86_64") as machine,
            patch.object(MODULE, "git", return_value=(str(self.root) + "\n").encode()),
            patch.object(MODULE.subprocess, "run", side_effect=execute),
        ):
            self.assertEqual(MODULE.run_gate(self.root, manifest), 1)
        self.assertEqual(namespace_reads, set(namespace_paths))
        system.assert_called_once()
        machine.assert_called_once()
        self.assertEqual(captured["cwd"], self.root)
        self.assertEqual(
            captured["env"]["PATH"], manifest["tool_path"] + ":" + manifest["nix_bin"]
        )
        self.assertTrue(
            all(name not in captured["env"] for name in inherited if name != "PATH")
        )
        self.assertEqual(captured["env"]["npm_config_offline"], "true")
        self.assertEqual(
            captured["command"],
            [CLI, "--verbose", "--max-jobs", "1", "--cores", "2", "--offline", "test"],
        )


if __name__ == "__main__":
    unittest.main()
