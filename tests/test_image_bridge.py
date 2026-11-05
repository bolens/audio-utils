"""Exact source, native producer and accepted-digest promotion contracts."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

DIRECTORY = Path(__file__).resolve().parents[1] / "scripts/ci"
SPEC = importlib.util.spec_from_file_location("bridge", DIRECTORY / "woodpecker-verify-image.py")
bridge = importlib.util.module_from_spec(SPEC)
with patch.object(sys, "path", [str(DIRECTORY), *sys.path]):
    SPEC.loader.exec_module(bridge)
SHA, DIGEST, CONFIG = "a" * 40, "sha256:" + "b" * 64, "sha256:" + "c" * 64


class ImageBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        event = self.root / "event.json"
        event.write_text(json.dumps({"inputs": {"woodpecker_bridge": "true", "source_sha": SHA,
            "image_digest": DIGEST, "config_digest": CONFIG, "pipeline_number": "12"}}))
        self.env = {"GITHUB_ACTIONS": "true", "WOODPECKER_PUBLISHING_ENABLED": "true", "GITHUB_REPOSITORY": bridge.REPOSITORY,
            "GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REF": "refs/heads/main",
            "GITHUB_WORKFLOW_REF": bridge.REPOSITORY + "/.github/workflows/docker.yml@refs/heads/main",
            "GITHUB_ACTOR_ID": "352757955", "GITHUB_SHA": SHA, "GITHUB_EVENT_PATH": str(event)}
        self.record = {"repository": bridge.REPOSITORY, "commit": SHA, "image": bridge.IMAGE,
            "digest": DIGEST, "configDigest": CONFIG, "candidate": f"candidate-{SHA}-12",
            "builder": "https://woodpecker.bolens.dev/repos/11/pipeline/12"}

    def test_exact_app_dispatch_and_checkout(self):
        with patch.dict(os.environ, self.env, clear=True), patch.object(bridge, "run", side_effect=[SHA, ""]), patch.object(bridge, "api", return_value={"sha": SHA}):
            self.assertEqual(bridge.context(), self.record)

    def test_wrong_actor_forge_workflow_sha_and_superseded_main_denied(self):
        for key, value in [("GITHUB_ACTOR_ID", "123"), ("GITHUB_REPOSITORY", "fork/other"),
                           ("GITHUB_WORKFLOW_REF", "wrong"), ("GITHUB_REF", "refs/pull/1/merge"),
                           ("GITHUB_SHA", "d" * 40)]:
            with self.subTest(key=key), patch.dict(os.environ, {**self.env, key: value}, clear=True), patch.object(bridge, "run", side_effect=[SHA, ""]), self.assertRaises(ValueError):
                bridge.context()
        with patch.dict(os.environ, self.env, clear=True), patch.object(bridge, "run", side_effect=[SHA, ""]), patch.object(bridge, "api", return_value={"sha": "d" * 40}), self.assertRaisesRegex(ValueError, "superseded"):
            bridge.context()

    def test_runtime_source_uid_platform_and_candidate_digest_binding(self):
        image = {"Id": CONFIG, "Os": "linux", "Architecture": "amd64", "Config": {"User": "10001:10001", "Labels": {
            "org.opencontainers.image.revision": SHA, "org.opencontainers.image.source": "https://github.com/" + bridge.REPOSITORY}}}
        replies = [json.dumps({"Digest": DIGEST}), json.dumps({"config": {"digest": CONFIG}}), json.dumps([image])]
        with patch.object(bridge, "run", side_effect=replies):
            bridge.candidate_identity(self.record)
        mutations = [(0, {"Digest": "sha256:" + "d" * 64}),
                     (1, {"config": {"digest": "sha256:" + "d" * 64}}),
                     (2, [{**image, "Config": {**image["Config"], "User": "0"}}])]
        for index, value in mutations:
            replacement = json.dumps(value)
            bad = list(replies)
            bad[index] = replacement
            with self.subTest(index=index), patch.object(bridge, "run", side_effect=bad), self.assertRaises(ValueError):
                bridge.candidate_identity(self.record)

    def test_verify_requires_native_success_before_runtime_and_records_only_after(self):
        with patch.object(bridge, "context", return_value=self.record), patch.object(bridge, "wait_for_native_success", side_effect=ValueError("native failed")), patch.object(bridge, "run") as run:
            with self.assertRaisesRegex(ValueError, "native failed"):
                bridge.verify()
            run.assert_not_called()

    def test_conflicting_immutable_tag_and_stale_main_never_promote(self):
        (self.root / "verified.json").write_text(json.dumps(self.record))
        for prior, head in [("sha256:" + "d" * 64, SHA), (None, "d" * 40)]:
            with self.subTest(prior=prior), patch.object(bridge, "OUTPUT", self.root), patch.object(bridge, "context", return_value=self.record), patch.object(bridge, "candidate_identity"), patch.object(bridge, "inspect_alias", return_value=prior), patch.object(bridge, "api", return_value={"sha": head}), patch.object(bridge, "run") as run:
                with self.assertRaises(ValueError):
                    bridge.promote()
                run.assert_not_called()

    def test_alias_auth_failure_is_not_absence_and_children_strip_secrets(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "unauthorized")), self.assertRaisesRegex(ValueError, "alias state"):
            bridge.inspect_alias("latest")
        with patch.dict(os.environ, {"GH_TOKEN": "test", "GITHUB_TOKEN": "test", "WOODPECKER_PUBLISH_LEASE": "test", "GIT_TRACE": "1"}, clear=True):
            self.assertFalse({"GH_TOKEN", "GITHUB_TOKEN", "WOODPECKER_PUBLISH_LEASE", "GIT_TRACE"} & bridge.environment().keys())
            self.assertEqual(bridge.environment(auth=True)["GH_TOKEN"], "test")


class NativeHandoffTests(unittest.TestCase):
    def test_native_archive_binds_config_bytes_source_uid_and_pipeline(self):
        import hashlib
        import io
        import tarfile
        spec = importlib.util.spec_from_file_location("archive_publisher", DIRECTORY / "woodpecker-publish.py")
        publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(publisher)
        with tempfile.TemporaryDirectory() as directory:
            config = json.dumps({"os": "linux", "architecture": "amd64", "config": {
                "User": "10001:10001", "Labels": {"org.opencontainers.image.revision": SHA,
                "org.opencontainers.image.source": "https://github.com/" + bridge.REPOSITORY}}}).encode()
            name = "sha256:" + hashlib.sha256(config).hexdigest()
            manifest = json.dumps([{"Config": name, "RepoTags": [f"{bridge.IMAGE}:candidate-{SHA}-12"]}]).encode()
            with tarfile.open(Path(directory) / "image.tar", "w") as archive:
                for filename, payload in [(name, config), ("manifest.json", manifest)]:
                    member = tarfile.TarInfo(filename)
                    member.size = len(payload)
                    archive.addfile(member, io.BytesIO(payload))
            with patch.object(publisher, "OUTPUT", Path(directory)), patch.dict(os.environ, {"CI_PIPELINE_NUMBER": "12"}, clear=True):
                self.assertEqual(publisher.archive_config(SHA, ""), name)
                with self.assertRaisesRegex(ValueError, "canonical source"):
                    publisher.archive_config("d" * 40, "")
                with patch.dict(os.environ, {"CI_PIPELINE_NUMBER": "13"}), self.assertRaisesRegex(ValueError, "another pipeline"):
                    publisher.archive_config(SHA, "")

    def test_exact_native_receipt_dispatches_and_returns_pending(self):
        spec = importlib.util.spec_from_file_location("publisher_bridge", DIRECTORY / "woodpecker-publish.py")
        publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(publisher)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            record = {"repository": bridge.REPOSITORY, "commit": SHA, "image": bridge.IMAGE,
                      "digest": DIGEST, "configDigest": CONFIG,
                      "builder": "https://woodpecker.bolens.dev/repos/11/pipeline/12"}
            (output / "image-manifest.json").write_text(json.dumps(record))
            with patch.object(publisher, "OUTPUT", output), patch.object(publisher, "guard", return_value=(SHA, "")), patch.dict(os.environ, {"CI_PIPELINE_NUMBER": "12"}, clear=True), patch.object(publisher, "api") as api:
                publisher.handoff()
                self.assertEqual(api.call_args.args[2], {"ref": "main", "inputs": {
                    "woodpecker_bridge": "true", "source_sha": SHA, "image_digest": DIGEST,
                    "config_digest": CONFIG, "pipeline_number": "12"}})
                self.assertEqual(json.loads((output / "handoff.json").read_text())["status"], "pending-runtime-and-promotion")
                record["builder"] = "https://woodpecker.bolens.dev/repos/12/pipeline/12"
                (output / "image-manifest.json").write_text(json.dumps(record))
                api.reset_mock()
                with self.assertRaisesRegex(ValueError, "handoff differs"):
                    publisher.handoff()
                api.assert_not_called()


if __name__ == "__main__":
    unittest.main()
