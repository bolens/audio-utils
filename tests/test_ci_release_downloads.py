"""CI downloads retain checksum and exact-member guards without REST quota."""
import hashlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/install-rolling-ffmpeg.py"
SPEC = importlib.util.spec_from_file_location("rolling_ffmpeg", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
ROLLING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ROLLING)


def archive_bytes(*, link=False, missing=False):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:xz") as archive:
        for binary in ("ffmpeg", "ffprobe"):
            if missing and binary == "ffprobe":
                continue
            member = tarfile.TarInfo(f"ffmpeg-master-latest-linux64-gpl/bin/{binary}")
            if link and binary == "ffprobe":
                member.type = tarfile.SYMTYPE
                member.linkname = "/must-not-read"
                archive.addfile(member)
            else:
                content = b"#!/bin/sh\nexit 0\n"
                member.size = len(content)
                archive.addfile(member, io.BytesIO(content))
    return stream.getvalue()


class ReleaseDownloadTests(unittest.TestCase):
    def test_manifest_requires_exact_unambiguous_sha256_entry(self):
        valid = "a" * 64 + "  " + ROLLING.NAME + "\n"
        self.assertEqual(ROLLING.checksum_for(valid), "a" * 64)
        self.assertEqual(ROLLING.checksum_for(valid.replace("  ", " *")), "a" * 64)
        for content in ("", valid + valid, valid.replace("a" * 64, "invalid"),
                        valid.replace(ROLLING.NAME, "../" + ROLLING.NAME)):
            with self.subTest(content=content), self.assertRaises(ValueError):
                ROLLING.checksum_for(content)

    def invoke(self, content, *, wrong_hash=False, http_failure=False):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        destination = Path(scratch.name)
        sentinel = destination / "ffmpeg"
        sentinel.write_bytes(b"preserve-until-verified")
        digest = "0" * 64 if wrong_hash else hashlib.sha256(content).hexdigest()
        manifest = (digest + "  " + ROLLING.NAME + "\n").encode()
        calls = []

        def request(args, **kwargs):
            calls.append((args, kwargs))
            if http_failure:
                raise subprocess.CalledProcessError(22, "curl")
            output = Path(args[args.index("--output") + 1])
            output.write_bytes(manifest if args[-1].endswith("checksums.sha256") else content)
            return subprocess.CompletedProcess(args, 0)

        return destination, sentinel, calls, request

    def test_verified_official_assets_install_only_bounded_regular_binaries(self):
        destination, _, calls, request = self.invoke(archive_bytes())
        with patch.object(ROLLING.subprocess, "run", side_effect=request):
            ROLLING.install(destination)
        for binary in ("ffmpeg", "ffprobe"):
            self.assertEqual((destination / binary).read_bytes(), b"#!/bin/sh\nexit 0\n")
            self.assertEqual((destination / binary).stat().st_mode & 0o777, 0o755)
        self.assertEqual([args[-1] for args, _ in calls], [
            ROLLING.BASE + "/checksums.sha256", ROLLING.BASE + "/" + ROLLING.NAME,
        ])
        for args, kwargs in calls:
            self.assertNotIn("api.github.com", " ".join(args))
            self.assertEqual(kwargs, {"check": True, "timeout": 360})
            self.assertEqual(args[args.index("--retry") + 1], "3")
            self.assertEqual(args[args.index("--proto") + 1], "=https")
            self.assertEqual(args[args.index("--proto-redir") + 1], "=https")
            for option in ("--max-time", "--connect-timeout", "--retry-max-time", "--max-filesize"):
                self.assertGreater(int(args[args.index(option) + 1]), 0)

    def test_hash_mismatch_member_link_and_missing_binary_preserve_destination(self):
        for content, wrong_hash in ((archive_bytes(), True), (archive_bytes(link=True), False),
                                    (archive_bytes(missing=True), False)):
            with self.subTest(wrong_hash=wrong_hash):
                destination, sentinel, calls, request = self.invoke(content, wrong_hash=wrong_hash)
                with patch.object(ROLLING.subprocess, "run", side_effect=request), self.assertRaises((ValueError, KeyError)):
                    ROLLING.install(destination)
                self.assertEqual(sentinel.read_bytes(), b"preserve-until-verified")
                self.assertFalse((destination / "ffprobe").exists())
                self.assertEqual(len(calls), 2)  # No retry after a checksum/member failure.

    def test_oversized_manifest_stops_before_archive_or_destination_write(self):
        destination, sentinel, calls, _ = self.invoke(archive_bytes())

        def oversized(args, **kwargs):
            calls.append((args, kwargs))
            maximum = int(args[args.index("--max-filesize") + 1])
            Path(args[args.index("--output") + 1]).write_bytes(b"x" * (maximum + 1))
            return subprocess.CompletedProcess(args, 0)

        with patch.object(ROLLING.subprocess, "run", side_effect=oversized), self.assertRaises(ValueError):
            ROLLING.install(destination)
        self.assertEqual(len(calls), 1)
        self.assertEqual(sentinel.read_bytes(), b"preserve-until-verified")

    def test_http_failure_is_not_treated_as_an_absent_manifest_or_install_success(self):
        destination, sentinel, calls, request = self.invoke(archive_bytes(), http_failure=True)
        with patch.object(ROLLING.subprocess, "run", side_effect=request), self.assertRaises(subprocess.CalledProcessError):
            ROLLING.install(destination)
        self.assertEqual(len(calls), 1)
        self.assertEqual(sentinel.read_bytes(), b"preserve-until-verified")


if __name__ == "__main__":
    unittest.main()
