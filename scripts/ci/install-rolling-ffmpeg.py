#!/usr/bin/env python3
"""Install the rolling FFmpeg lane using its upstream published SHA-256 list."""
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

BASE = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
NAME = "ffmpeg-master-latest-linux64-gpl.tar.xz"


def download(name, destination, maximum):
    """Bound downloads and transient HTTP retries; never use anonymous REST quota."""
    transfer_seconds = 180
    retry_window_seconds = 300
    process_seconds = 360
    if name == NAME:
        transfer_seconds = 600
        retry_window_seconds = 600
        # curl's retry window limits when another attempt can start, not when
        # its final transfer must end. Bound both plus process cleanup overhead.
        process_seconds = retry_window_seconds + transfer_seconds + 60
    subprocess.run([
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--proto", "=https", "--proto-redir", "=https",
        "--connect-timeout", "15", "--max-time", str(transfer_seconds),
        "--retry", "3", "--retry-delay", "5", "--retry-max-time", str(retry_window_seconds),
        "--max-filesize", str(maximum), "--user-agent", "audio-utils-ci/1",
        "--header", "Cache-Control: no-cache", "--output", str(destination),
        f"{BASE}/{name}",
    ], check=True, timeout=process_seconds)
    if destination.stat().st_size > maximum:
        raise ValueError("upstream release asset exceeds its size limit")


def checksum_for(text):
    matches = []
    for line in text.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1].removeprefix("*") == NAME:
            if not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
                raise ValueError("invalid upstream FFmpeg SHA-256")
            matches.append(fields[0])
    if len(matches) != 1:
        raise ValueError("upstream FFmpeg checksum is missing or ambiguous")
    return matches[0]


def install(destination=Path("/usr/local/bin")):
    if not destination.is_dir():
        raise ValueError("FFmpeg destination directory must already exist")
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory)
        checksums = scratch / "checksums.sha256"
        download(checksums.name, checksums, 256 * 1024)
        expected = checksum_for(checksums.read_text(encoding="utf-8"))
        archive = scratch / NAME
        download(NAME, archive, 512 * 1024 * 1024)
        with archive.open("rb") as data:
            actual = hashlib.file_digest(data, "sha256").hexdigest()
        if actual != expected:
            # The mutable latest tag can move between these two reads. Do not
            # install or retry mismatching bytes under an earlier manifest.
            raise ValueError("rolling FFmpeg checksum mismatch")
        staged = []
        with tarfile.open(archive, "r:xz") as source:
            members = source.getmembers()
            if len(members) > 4096 or sum(member.size for member in members) > 2 * 1024**3:
                raise ValueError("FFmpeg archive exceeds its size or entry limit")
            for binary in ("ffmpeg", "ffprobe"):
                member = source.getmember(f"ffmpeg-master-latest-linux64-gpl/bin/{binary}")
                if not member.isfile() or not 0 < member.size <= 512 * 1024**2:
                    raise ValueError("FFmpeg binary is not a bounded regular archive member")
                target = scratch / binary
                with source.extractfile(member) as data, target.open("wb") as output:
                    shutil.copyfileobj(data, output, length=1024 * 1024)
                if target.stat().st_size != member.size:
                    raise ValueError("FFmpeg binary extraction was incomplete")
                staged.append(target)
        # Validate and stage both exact members before modifying the destination.
        for target in staged:
            installed = destination / target.name
            shutil.copyfile(target, installed)
            installed.chmod(0o755)
    print(f"rolling FFmpeg test asset: sha256:{expected}")


if __name__ == "__main__":
    install()
