# Third-party software and licenses

audio-utils itself is [MIT](../LICENSE). It contains no copied third-party
source code. It does, however, interact with third-party software, and two
vendored test fixtures were produced with third-party encoders. Notices below.

## Invoked, not bundled

The tools drive external programs at runtime (`ffmpeg`/`ffprobe`, `flac`/
`metaflac`, `sox`, `cdparanoia`, `mpcenc`, `rsgain`/`loudgain`, `fpcalc`,
`mediainfo`, `dvdbackup`, etc. — see [requirements.md](requirements.md)).
None of them are distributed with this repository; install them from your
distro under their own licenses (e.g. ffmpeg is LGPL/GPL, FLAC is BSD/GPL,
sox is LGPL/GPL). Nothing here links against or embeds their code.

## Monkey's Audio (APE)

[`scripts/ape-codec.sh`](../scripts/ape-codec.sh) downloads the official
Monkey's Audio SDK from monkeysaudio.com onto *your* machine, verifies it,
and builds the `mac` binary locally. The SDK is **not** included in this
repository.

- Copyright © Matthew T. Ashland
- License: [3-clause BSD](https://www.monkeysaudio.com/license.html)
  (since version 10.18; all versions pinned by the script are newer)
- The SDK zip ships its own `License.txt`; if you redistribute a `mac`
  binary built by the script, the BSD license requires you to reproduce
  the copyright notice and disclaimer with it.

## Shorten (SHN)

`tests/assets/tone.shn` is a 0.5 s sine tone encoded once, non-commercially,
with shorten 3.6.1 (see [tests/assets/README.md](../tests/assets/README.md)).
The shorten *software* — © Tony Robinson and SoftSound, free for decoding
and non-commercial encoding, no sale or commercial encoding without
permission — is **not** distributed here, and this repo never invokes it;
SHN decoding uses ffmpeg. The fixture is just encoder output (a generated
sine wave), not a derivative of the encoder.

## TAK (Takc)

TAK encoding uses the official `Takc` CLI, proprietary freeware by Thomas
Becker that **you** download from the upstream TAK site and point to via
`AUDIO_UTILS_TAKC` (see [tak.md](tak.md)). It is not distributed here.

## Test fixtures

All other test media is generated at test time by `tests/fixtures.sh` using
ffmpeg/flac. The only vendored binaries are `tests/assets/tone.shn` and
`tests/assets/tone.ape` described above; both are original sine tones
created for this project and are covered by the repo's MIT license.

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [tak.md](tak.md) · [root README](../README.md)
