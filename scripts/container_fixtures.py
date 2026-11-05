"""Disposable Docker volume transport for runtime acceptance fixtures."""
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import uuid


def fixture_archive(inputs, outputs, uid, gid):
    stream = io.BytesIO()

    def ownership(member):
        member.uid, member.gid = uid, gid
        member.uname = member.gname = ""
        return member

    with tarfile.open(fileobj=stream, mode="w") as archive:
        archive.add(inputs, arcname="input/data", filter=ownership)
        archive.add(outputs, arcname="output/data", filter=ownership)
    return stream.getvalue()


def run_volume(engine, image, options, command, inputs, outputs, uid, gid):
    """Run without daemon-host bind paths, retaining numeric output ownership."""
    prefix = "audio-utils-fixture-" + uuid.uuid4().hex
    volumes, containers = [], []

    def invoke(*arguments, check=True, **kwargs):
        kwargs.setdefault("text", True)
        return subprocess.run([engine, *arguments], check=check, capture_output=True,
                              timeout=180, **kwargs)

    def remove_container(name):
        invoke("rm", "-f", "-v", name)
        containers.remove(name)

    try:
        for suffix in ("input", "output"):
            name = prefix + "-" + suffix
            if invoke("volume", "inspect", name, check=False).returncode == 0:
                raise RuntimeError("refusing an existing fixture volume")
            volumes.append(name)
            invoke("volume", "create", name)
        populate = prefix + "-populate"
        containers.append(populate)
        invoke("create", "--name", populate, "--network=none", "--cap-drop=ALL",
               "--security-opt=no-new-privileges", "--volume", volumes[0] + ":/fixtures/input",
               "--volume", volumes[1] + ":/fixtures/output", "--entrypoint=/bin/true", "--", image)
        invoke("cp", "--archive", "-", populate + ":/fixtures/", text=False,
               input=fixture_archive(inputs, outputs, uid, gid))
        remove_container(populate)
        runtime = prefix + "-runtime"
        containers.append(runtime)
        invoke("create", "--name", runtime, "--cpus=2", "--memory=4g",
               "--memory-swap=4g", "--pids-limit=256", *options,
               "--mount", f"type=volume,src={volumes[0]},dst=/input,volume-subpath=data,readonly",
               "--mount", f"type=volume,src={volumes[1]},dst=/output,volume-subpath=data",
               "--", image, *map(str, command))
        started = invoke("start", "--attach", runtime, check=False)
        state = json.loads(invoke("inspect", "--format", "{{json .State}}", runtime).stdout)
        if state.get("Status") != "exited" or type(state.get("ExitCode")) is not int:
            raise RuntimeError("fixture container did not complete normally")
        if started.returncode not in (0, state["ExitCode"]):
            raise RuntimeError("container attach failed independently of the fixture command")
        with tempfile.TemporaryDirectory(prefix="audio-utils-copyback-") as directory:
            snapshot = Path(directory) / "output"
            invoke("cp", "--archive", runtime + ":/output", str(snapshot))
            for path in [snapshot, *snapshot.rglob("*")]:
                if path.is_symlink() or not (path.is_file() or path.is_dir()):
                    raise RuntimeError("refusing unsafe output fixture entry")
            # Replace the complete snapshot so deletions cannot be hidden by merging.
            shutil.rmtree(outputs)
            shutil.move(str(snapshot), str(outputs))
        return subprocess.CompletedProcess([engine, "run", image, *map(str, command)],
                                           state["ExitCode"], started.stdout, started.stderr)
    finally:
        # Preserve the primary failure; cleanup failures still make successful runs fail.
        import sys
        failed = sys.exc_info()[0] is not None
        cleanup_failed = False
        for arguments in (["rm", "-f", "-v", name] for name in reversed(containers)):
            try:
                cleanup_failed |= invoke(*arguments, check=False).returncode != 0
            except (subprocess.SubprocessError, OSError):
                cleanup_failed = True
        for arguments in (["volume", "rm", name] for name in reversed(volumes)):
            try:
                cleanup_failed |= invoke(*arguments, check=False).returncode != 0
            except (subprocess.SubprocessError, OSError):
                cleanup_failed = True
        if cleanup_failed:
            message = "fixture cleanup failed for owned resources: " + ", ".join(containers + volumes)
            if failed:
                print(message, file=sys.stderr)
            else:
                raise RuntimeError(message)
