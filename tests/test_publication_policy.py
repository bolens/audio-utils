"""Publication authorization and immutable-candidate denial cases, without network writes."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "scripts/ci/woodpecker-publish.py"
spec = importlib.util.spec_from_file_location("publisher", SOURCE)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)
SHA = "a" * 40


class PublicationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.env = {"CI_FORGE_TYPE": "github", "CI_FORGE_URL": "https://github.com",
                    "CI_REPO": publisher.REPOSITORY, "CI_COMMIT_SHA": SHA,
                    "CI_PIPELINE_NUMBER": "12", "CI_PIPELINE_URL": "https://ci.example/p/12"}
        if publisher.REPOSITORY == "bolens/audio-utils":
            self.env.update(CI_PIPELINE_EVENT="push", CI_COMMIT_BRANCH="main",
                            CI_COMMIT_REF="refs/heads/main")
        else:
            self.env.update(CI_PIPELINE_EVENT="tag", CI_COMMIT_TAG="v1.2.3",
                            CI_COMMIT_REF="refs/tags/v1.2.3")
        self.environment = patch.dict(os.environ, self.env, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.git = patch.object(publisher, "run", side_effect=lambda *a, **kw: SHA if a[1:] == ("rev-parse", "HEAD") else "")
        self.git.start()
        self.addCleanup(self.git.stop)

    def test_lease_is_redeemed_at_fixed_endpoint_and_cached_without_trace_env(self):
        reply = io.BytesIO(json.dumps({"token": "unit-test-token", "expires_at": "1970-01-01T01:23:20Z"}).encode())
        with patch.dict(os.environ, {"WOODPECKER_PUBLISH_LEASE": "unit-test-lease", "GH_DEBUG": "api", "GIT_TRACE": "1"}), patch.object(publisher, "_GITHUB_CREDENTIAL", None), patch("time.time", return_value=1000), patch("urllib.request.build_opener") as build:
            build.return_value.open.return_value = reply
            first = publisher.github_environment()
            second = publisher.github_environment()
            self.assertEqual(first["GH_TOKEN"], "unit-test-token")
            self.assertEqual(second["GH_HOST"], "github.com")
            self.assertFalse({"GH_DEBUG", "GIT_TRACE", "WOODPECKER_PUBLISH_LEASE"} & first.keys())
            build.return_value.open.assert_called_once()
            request = build.return_value.open.call_args.args[0]
            self.assertEqual(request.full_url, publisher.CREDENTIAL_ENDPOINT)
            self.assertEqual(request.method, "POST")
            body = json.loads(request.data)
            self.assertRegex(body.pop("request_id"), "^[0-9a-f]{32}$")
            self.assertEqual(body, {"lease": "unit-test-lease", "repository": publisher.REPOSITORY, "commit": SHA, "purpose": "github"})
            self.assertIsNone(build.call_args.args[0].redirect_request(None, None, 302, "", {}, "https://other.example"))

    def test_nearly_expired_token_refreshes_and_redemption_errors_are_redacted(self):
        reply = io.BytesIO(json.dumps({"token": "refreshed-test-token", "expires_at": 5000}).encode())
        with patch.dict(os.environ, {"WOODPECKER_PUBLISH_LEASE": "unit-test-lease"}), patch.object(publisher, "_GITHUB_CREDENTIAL", ("old-test-token", 1100)), patch("time.time", return_value=1000), patch("urllib.request.build_opener") as build:
            build.return_value.open.return_value = reply
            self.assertEqual(publisher.github_environment()["GH_TOKEN"], "refreshed-test-token")
            build.return_value.open.assert_called_once()
        with patch.dict(os.environ, {"WOODPECKER_PUBLISH_LEASE": "unit-test-lease"}), patch.object(publisher, "_GITHUB_CREDENTIAL", None), patch("urllib.request.build_opener") as build:
            build.return_value.open.side_effect = RuntimeError("unit-test-lease must not leak")
            with self.assertRaisesRegex(RuntimeError, "^publication credential redemption failed$"):
                publisher.github_environment()

    def test_local_subprocesses_do_not_inherit_credentials_or_trace_settings(self):
        self.git.stop()
        with patch.dict(os.environ, {"GH_TOKEN": "unit-test-token", "GITHUB_TOKEN": "other-test-token", "WOODPECKER_PUBLISH_LEASE": "unit-test-lease", "GIT_TRACE": "1", "GH_DEBUG": "api"}), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as process:
            publisher.run("git", "status", "--porcelain")
            environment = process.call_args.kwargs["env"]
            self.assertFalse({"GH_TOKEN", "GITHUB_TOKEN", "WOODPECKER_PUBLISH_LEASE", "GIT_TRACE", "GH_DEBUG"} & environment.keys())
            self.assertEqual(environment["GIT_CONFIG_GLOBAL"], "/dev/null")

    def test_exact_native_context(self):
        self.assertEqual(publisher.context()[0], SHA)

    def test_wrong_forge_url_repository_and_event_denied_before_api(self):
        for key, value in [("CI_FORGE_TYPE", "gitea"), ("CI_FORGE_URL", "https://attacker.example"),
                           ("CI_REPO", "fork/other"), ("CI_PIPELINE_EVENT", "pull_request"),
                           ("CI_PIPELINE_EVENT", "manual"), ("CI_COMMIT_REF", "refs/heads/feature")]:
            with self.subTest(key=key, value=value), patch.dict(os.environ, {key: value}), patch.object(publisher, "api") as api:
                with self.assertRaises(ValueError):
                    publisher.guard()
                api.assert_not_called()

    def test_modified_or_wrong_checkout_denied(self):
        for answers in [["b" * 40], [SHA, " M package.json"]]:
            with self.subTest(answers=answers), patch.object(publisher, "run", side_effect=answers):
                with self.assertRaises(ValueError):
                    publisher.context()

    def test_disabled_and_unreadable_setting_deny_writes(self):
        for value in [{"value": "false"}, {}, subprocess.CalledProcessError(1, ["gh", "api"])]:
            with self.subTest(value=value):
                kwargs = {"side_effect": value} if isinstance(value, Exception) else {"return_value": value}
                with patch.object(publisher, "api", **kwargs):
                    with self.assertRaises(publisher.PublicationDisabled):
                        publisher.guard()

    def test_existing_immutable_image_denied(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "OUTPUT", Path(directory)), patch.object(publisher, "guard", return_value=(SHA, "")), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "{}", "")):
            with self.assertRaises(ValueError):
                publisher.prepare()
            self.assertFalse((Path(directory) / "kaniko.env").exists())

    def test_retry_of_existing_candidate_denied(self):
        replies = [subprocess.CompletedProcess([], 1, "", "manifest unknown"),
                   subprocess.CompletedProcess([], 0, "{}", "")]
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "OUTPUT", Path(directory)), patch.object(publisher, "guard", return_value=(SHA, "")), patch.object(subprocess, "run", side_effect=replies) as probe:
            with self.assertRaises(ValueError):
                publisher.prepare()
            self.assertEqual(probe.call_count, 2)
            self.assertTrue(probe.call_args.args[0][-1].endswith(f":candidate-{SHA}-12"))
            self.assertFalse((Path(directory) / "kaniko.env").exists())

    def test_network_or_auth_failure_does_not_imply_image_absence(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "OUTPUT", Path(directory)), patch.object(publisher, "guard", return_value=(SHA, "")), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "unauthorized")):
            with self.assertRaises(ValueError):
                publisher.prepare()
            self.assertFalse((Path(directory) / "kaniko.env").exists())

    def test_build_tag_is_per_pipeline_candidate_without_alias(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "OUTPUT", Path(directory)), patch.object(publisher, "guard", return_value=(SHA, "")), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "manifest unknown")):
            publisher.prepare()
            self.assertEqual((Path(directory) / "kaniko.env").read_text(), f"PLUGIN_TAGS=candidate-{SHA}-12\n")

    def test_manifest_rejects_foreign_revision(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "OUTPUT", Path(directory)), patch.object(publisher, "guard", return_value=(SHA, "")), patch.object(publisher, "run", return_value='{"Digest":"sha256:' + "b" * 64 + '","Labels":{"org.opencontainers.image.revision":"foreign"}}'):
            (Path(directory) / "image.digest").write_text("sha256:" + "b" * 64)
            with self.assertRaises(ValueError):
                publisher.manifest()
            self.assertFalse((Path(directory) / "image-manifest.json").exists())


if __name__ == "__main__":
    unittest.main()
