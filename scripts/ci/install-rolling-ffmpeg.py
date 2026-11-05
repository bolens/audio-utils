#!/usr/bin/env python3
"""Install the rolling FFmpeg test lane after verifying GitHub's asset SHA-256."""
import hashlib
import json
from pathlib import Path
import re
import tarfile
import tempfile
import urllib.request

API = "https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/latest"
NAME = "ffmpeg-master-latest-linux64-gpl.tar.xz"
with urllib.request.urlopen(API, timeout=60) as response:
    release = json.load(response)
asset = next(item for item in release["assets"] if item["name"] == NAME)
if not re.fullmatch(r"sha256:[0-9a-f]{64}", asset.get("digest", "")):
    raise ValueError("rolling FFmpeg asset has no verified SHA-256 metadata")
url = asset["browser_download_url"]
if url != f"https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/{NAME}":
    raise ValueError("unexpected FFmpeg download origin")
with tempfile.TemporaryDirectory() as directory:
    archive = Path(directory) / NAME
    digest = hashlib.sha256()
    with urllib.request.urlopen(url, timeout=120) as source, archive.open("wb") as target:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
            target.write(chunk)
    if f"sha256:{digest.hexdigest()}" != asset["digest"]:
        raise ValueError("rolling FFmpeg checksum mismatch")
    with tarfile.open(archive, "r:xz") as source:
        for binary in ("ffmpeg", "ffprobe"):
            member = source.getmember(f"ffmpeg-master-latest-linux64-gpl/bin/{binary}")
            if not member.isfile():
                raise ValueError("FFmpeg binary is not a regular archive member")
            destination = Path("/usr/local/bin") / binary
            with source.extractfile(member) as data:
                destination.write_bytes(data.read())
            destination.chmod(0o755)
print(f"rolling FFmpeg test asset: {asset['digest']}")
