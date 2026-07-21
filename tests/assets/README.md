# Vendored test assets

Small binary fixtures for formats whose encoders cannot run in CI or be
rebuilt on demand. Everything generatable at test time lives in
`tests/fixtures.sh` instead — vendor an asset here only as a last resort,
keep it tiny, and document exactly how it was produced.

## tone.shn (Shorten)

0.5 s stereo 16-bit 44.1 kHz sine (440 Hz), losslessly compressed with
shorten 3.6.1. No distro we target still packages a shorten encoder
(ffmpeg decodes SHN but cannot encode it), so the file is vendored.

Regenerate with:

```bash
# Source: http://etree.org/shnutils/shorten/ (3.6.1, via web.archive.org)
curl -fsSL -o shorten.tar \
  "https://web.archive.org/web/20170607112233/http://etree.org/shnutils/shorten/dist/src/shorten-3.6.1.tar.gz"
tar xf shorten.tar && cd shorten-3.6.1
./configure && make CFLAGS="-O2 -D_XOPEN_SOURCE=700"   # needs swab(3)
ffmpeg -f lavfi -i "sine=frequency=440:duration=0.5:sample_rate=44100" \
  -ac 2 -c:a pcm_s16le tone.wav
src/shorten tone.wav tone.shn
```

Decoded audio MD5 (`ffmpeg -i tone.shn -map 0:a:0 -f md5 -`) must equal the
source WAV's: `ba7ed542b5cf1c48269e1b81681b54ee`.

## tone.ape (Monkey's Audio)

Same 0.5 s source WAV as `tone.shn`, compressed with Monkey's Audio 13.19
at normal level (`-c2000`). ffmpeg decodes APE but has no encoder; the mac
SDK is open source and builds on Linux with cmake, but no distro we target
packages it, so the file is vendored.

Regenerate with:

```bash
curl -fsSL -o mac.zip "https://monkeysaudio.com/files/MAC_1319_SDK.zip"
unzip mac.zip -d sdk && cd sdk
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
ffmpeg -f lavfi -i "sine=frequency=440:duration=0.5:sample_rate=44100" \
  -ac 2 -c:a pcm_s16le tone.wav
build/mac tone.wav tone.ape -c2000
```

Decoded audio MD5 must equal the same source WAV MD5 as above:
`ba7ed542b5cf1c48269e1b81681b54ee`.
