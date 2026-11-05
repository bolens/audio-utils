"""Archive, lifecycle and failure contracts for remote Docker fixture transport."""
import importlib.util
import io
import json
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("fixtures", Path(__file__).resolve().parents[1] / "scripts/container_fixtures.py")
fixtures = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fixtures)


class VolumeFixturesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.inputs, self.outputs = root / "input", root / "output"
        self.inputs.mkdir()
        self.outputs.mkdir()
        (self.inputs / '-雪 [*]\n.wav').write_bytes(b"original PCM fixture")
        (self.outputs / "old").write_text("must disappear")
        self.commands = []
        self.state = {"Status": "exited", "ExitCode": 2}
        self.bad_snapshot = False
        self.changed_input = False
        self.cleanup_failure = False

    def engine(self, command, **kwargs):
        args = command[1:]
        self.commands.append((args, kwargs))
        stdout = ""
        code = 0
        if args[:2] == ["volume", "inspect"]:
            code = 1
        elif args[0] == "inspect":
            stdout = json.dumps(self.state)
        elif args[0] == "cp" and args[-2].endswith(":/input"):
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                archive.add(self.inputs, arcname="input")
                if self.changed_input:
                    member = tarfile.TarInfo("input/unexpected")
                    archive.addfile(member)
            stdout = stream.getvalue()
        elif args[0] == "cp" and args[-2].endswith(":/output"):
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                root = tarfile.TarInfo("output")
                root.type, root.uid, root.gid, root.mode = tarfile.DIRTYPE, 10001, 10001, 0o755
                archive.addfile(root)
                member = tarfile.TarInfo("output/escape" if self.bad_snapshot else "output/new")
                if self.bad_snapshot:
                    member.type, member.linkname = tarfile.SYMTYPE, "/etc/passwd"
                    archive.addfile(member)
                else:
                    payload = b"new snapshot"
                    member.size, member.uid, member.gid, member.mode = len(payload), 0, 0, 0o644
                    archive.addfile(member, io.BytesIO(payload))
            stdout = stream.getvalue()
        elif self.cleanup_failure and args[:2] == ["volume", "rm"]:
            code = 1
        if kwargs.get("check") and code:
            raise subprocess.CalledProcessError(code, command)
        return subprocess.CompletedProcess(command, code, stdout, "")

    def invoke(self):
        return fixtures.run_volume("docker", "image:exact", ["--network=none", "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges", "--user", "10001:10001"], ["--help"], self.inputs, self.outputs, 10001, 10001)

    def test_archive_preserves_hostile_names_and_numeric_directory_ownership(self):
        data = fixtures.fixture_archive(self.inputs, self.outputs, 10001, 10002)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            self.assertIn('input/data/-雪 [*]\n.wav', archive.getnames())
            for member in archive:
                self.assertEqual((member.uid, member.gid, member.uname, member.gname), (10001, 10002, "", ""))
        self.assertEqual((self.inputs / '-雪 [*]\n.wav').read_bytes(), b"original PCM fixture")

    def test_volume_run_preserves_real_exit_and_replaces_snapshot_without_bind_paths(self):
        with patch.object(subprocess, "run", side_effect=self.engine):
            result = self.invoke()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(sorted(p.name for p in self.outputs.iterdir()), ["new"])
        create = next(args for args, _ in self.commands if args[0] == "create" and args[2].endswith("-runtime"))
        self.assertIn("--read-only", create)
        self.assertIn("--cap-drop=ALL", create)
        self.assertIn("--network=none", create)
        self.assertTrue(any("dst=/input,volume-subpath=data,readonly" in value for value in create))
        self.assertTrue(any("dst=/output,volume-subpath=data" in value for value in create))
        self.assertFalse(any("type=bind" in value for value in create))
        self.assertNotIn(str(self.inputs), create)
        self.assertEqual(create[create.index("--") + 1:], ["image:exact", "--help"])
        self.assertEqual(sum(args[:2] == ["volume", "rm"] for args, _ in self.commands), 2)

    def test_wrong_created_owner_survives_copyback_and_next_seed(self):
        with patch.object(subprocess, "run", side_effect=self.engine):
            result = self.invoke()
        self.assertEqual(result.fixture_owners["new"], (0, 0))
        data = fixtures.fixture_archive(self.inputs, self.outputs, 10001, 10001, result.fixture_owners)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            self.assertEqual((archive.getmember("output/data/new").uid, archive.getmember("output/data/new").gid), (0, 0))
            self.assertEqual(archive.getmember("output/data").uid, 10001)

    def test_export_paths_duplicates_and_special_files_fail_before_extraction(self):
        for name, kind in [("output/../escape", tarfile.REGTYPE), ("/output/escape", tarfile.REGTYPE),
                           ("other/file", tarfile.REGTYPE), ("output/fifo", tarfile.FIFOTYPE)]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode="w") as archive:
                    member = tarfile.TarInfo(name)
                    member.type = kind
                    archive.addfile(member)
                with self.assertRaisesRegex(RuntimeError, "unsafe output"):
                    fixtures.extract_snapshot(stream.getvalue(), Path(directory) / "output")
                self.assertFalse((Path(directory) / "output").exists())
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode="w") as archive:
            for _ in range(2):
                member = tarfile.TarInfo("output")
                member.type = tarfile.DIRTYPE
                archive.addfile(member)
        with tempfile.TemporaryDirectory() as directory, self.assertRaisesRegex(RuntimeError, "unsafe output"):
            fixtures.extract_snapshot(stream.getvalue(), Path(directory) / "output")

    def test_unsafe_output_is_rejected_before_local_fixture_deletion_and_cleanup_runs(self):
        self.bad_snapshot = True
        with patch.object(subprocess, "run", side_effect=self.engine), self.assertRaisesRegex(RuntimeError, "unsafe output"):
            self.invoke()
        self.assertTrue((self.outputs / "old").is_file())
        self.assertEqual(sum(args[:2] == ["volume", "rm"] for args, _ in self.commands), 2)

    def test_transport_failure_is_not_converted_into_an_expected_command_exit(self):
        self.state = {"Status": "created", "ExitCode": 0}
        self.cleanup_failure = True
        with patch.object(subprocess, "run", side_effect=self.engine), patch("sys.stderr", new_callable=io.StringIO), self.assertRaisesRegex(RuntimeError, "did not complete normally"):
            self.invoke()
        self.assertEqual(sum(args[:2] == ["volume", "rm"] for args, _ in self.commands), 2)

    def test_remote_input_mutation_fails_before_output_replacement(self):
        self.changed_input = True
        with patch.object(subprocess, "run", side_effect=self.engine), self.assertRaisesRegex(RuntimeError, "changed the read-only input"):
            self.invoke()
        self.assertTrue((self.outputs / "old").is_file())
        self.assertEqual(sum(args[:2] == ["volume", "rm"] for args, _ in self.commands), 2)

    def test_cleanup_failure_prevents_success(self):
        self.cleanup_failure = True
        with patch.object(subprocess, "run", side_effect=self.engine), self.assertRaisesRegex(RuntimeError, "cleanup failed"):
            self.invoke()


if __name__ == "__main__":
    unittest.main()
