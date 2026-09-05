#!/usr/bin/env python3
"""Exercise the built CLI image on disposable bind mounts, without networking."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import wave

SUITE = 'audio-utils'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default='docker')
    parser.add_argument('--image', default=SUITE + ':local')
    args = parser.parse_args()
    uid = os.getuid() or 10001
    gid = os.getgid() if os.getuid() else 10001
    with tempfile.TemporaryDirectory(prefix=SUITE + '-docker-') as tmp:
        root = Path(tmp)
        root.chmod(0o755)
        inputs, outputs = root / 'input', root / 'output'
        inputs.mkdir()
        outputs.mkdir()
        if os.getuid() == 0:
            os.chown(outputs, uid, gid)
        options = ['--rm', '--network=none', '--read-only', '--cap-drop=ALL',
                   '--security-opt=no-new-privileges', '--tmpfs', '/tmp:rw,nosuid,nodev,mode=1777',
                   '--user', f'{uid}:{gid}', '--workdir', '/output',
                   '--mount', f'type=bind,src={inputs},dst=/input,readonly',
                   '--mount', f'type=bind,src={outputs},dst=/output']
        if Path(args.engine).name == 'podman':
            options += ['--userns=keep-id']

        def run(*command, entry=None, code=0, default_user=False):
            opts = options.copy()
            if default_user:
                i = opts.index('--user')
                del opts[i:i + 2]
            if entry:
                opts += ['--entrypoint', entry]
            result = subprocess.run([args.engine, 'run', *opts, args.image, *map(str, command)],
                                    capture_output=True, text=True, timeout=180)
            if result.returncode != code:
                raise AssertionError(f'{command!r}: expected {code}, got {result.returncode}\n'
                                     f'{result.stdout}\n{result.stderr}')
            return result.stdout

        def unchanged(path, original):
            if path.read_bytes() != original:
                raise AssertionError(f'Source changed: {path.name!r}')

        def owned(path):
            if path.stat().st_uid != uid or path.stat().st_gid != gid:
                raise AssertionError(f'Output ownership differs from {uid}:{gid}: {path}')

        if run('-u', entry='id', default_user=True).strip() != '10001':
            raise AssertionError('Image must default to UID 10001')
        run('--help')
        run('not-a-tool', code=2)
        run('--version')
        run('-eu', '-c', '''
for mk in /opt/audio-utils/conversion/*/Makefile /opt/audio-utils/util/*/*/Makefile; do
    tool=${mk%/Makefile}
    tool=${tool##*/}
    /usr/local/bin/audio-utils "$tool" --help >/dev/null
done
''', entry='bash')
        name = '-雪 [*]\n.wav'
        source = inputs / name
        pcm = bytes((0, 0, 100, 0, 200, 0, 100, 0)) * 8000
        with wave.open(str(source), 'wb') as stream:
            stream.setparams((1, 2, 32000, 0, 'NONE', 'not compressed'))
            stream.writeframes(pcm)
        before = source.read_bytes()
        # Audio converters deliberately write siblings. Only the disposable copy is writable.
        shutil.copyfile(source, outputs / name)
        if os.getuid() == 0:
            os.chown(outputs / name, uid, gid)
        run('wav-to-flac', '-n', '-j', '1', '/output')
        converted = outputs / name.replace('.wav', '.flac')
        if converted.exists():
            raise AssertionError('Dry run wrote audio')
        run('wav-to-flac', '-j', '1', '/output')
        run('-t', '/output/' + converted.name, entry='flac')
        run('-v', 'error', '-i', '/output/' + converted.name, '-f', 's16le',
            '/output/decoded.pcm', entry='ffmpeg')
        if hashlib.sha256((outputs / 'decoded.pcm').read_bytes()).digest() != hashlib.sha256(pcm).digest():
            raise AssertionError('Decoded audio changed')
        owned(converted)
        original = converted.read_bytes()
        run('wav-to-flac', '-j', '1', '/output')
        unchanged(converted, original)
        unchanged(source, before)
        unchanged(outputs / name, before)
        run('../bin/bash', code=2)
        # A read-only input mount must not receive sibling outputs.
        run('wav-to-flac', '-j', '1', '/input', code=1)
        if list(inputs.glob('*.flac')):
            raise AssertionError('Wrote into a read-only input mount')
        if (outputs / 'failed').exists():
            raise AssertionError('Failed operation published output')
        print(SUITE + ': Docker acceptance passed (no skips)')


if __name__ == '__main__':
    main()
