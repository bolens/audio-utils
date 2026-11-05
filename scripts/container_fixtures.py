"""Disposable Docker volume transport for runtime acceptance fixtures."""
import hashlib
import io
import json
import shutil
import subprocess
import tarfile
import tempfile
import uuid
from pathlib import Path, PurePosixPath


def fixture_archive(inputs, outputs, uid, gid, owners=None):
    stream = io.BytesIO()

    def ownership(member):
        member.uid, member.gid = uid, gid
        if member.name == "output/data" or member.name.startswith("output/data/"):
            relative = PurePosixPath(member.name).relative_to("output/data").as_posix()
            if owners and relative in owners:
                member.uid, member.gid = owners[relative]
        member.uname = member.gname = ""
        return member

    with tarfile.open(fileobj=stream, mode="w") as archive:
        archive.add(inputs, arcname="input/data", filter=ownership)
        archive.add(outputs, arcname="output/data", filter=ownership)
    return stream.getvalue()


def extract_snapshot(data, destination, root_name="output"):
    """Validate Docker's numeric-owner export before safe local-user extraction."""
    owners, paths = {}, set()
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        members = archive.getmembers()
        for member in members:
            name = PurePosixPath(member.name)
            if (name.is_absolute() or ".." in name.parts or not name.parts
                    or name.parts[0] != root_name or name.as_posix() in paths
                    or not (member.isdir() or member.isfile())):
                raise RuntimeError(f"refusing unsafe {root_name} fixture entry")
            paths.add(name.as_posix())
            relative = name.relative_to(root_name).as_posix()
            if relative == "." and not member.isdir():
                raise RuntimeError(f"refusing unsafe {root_name} fixture root")
            owners[relative] = (member.uid, member.gid)
        if "." not in owners:
            raise RuntimeError(f"{root_name} snapshot has no root directory")
        # Numeric owners are evidence from the daemon, not a request to chown the
        # controller host. Keep them separately and copy only regular file bytes.
        destination.mkdir()
        directories = []
        for member in members:
            relative = PurePosixPath(member.name).relative_to(root_name)
            target = destination.joinpath(*relative.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                directories.append((target, member.mode & 0o777))
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(member.mode & 0o777)
        for directory, mode in sorted(directories, key=lambda item: len(item[0].parts), reverse=True):
            directory.chmod(mode)
    return owners


def fixture_contents(directory):
    """Compare names, kinds, permissions and bytes, without host numeric owners."""
    result = {}
    for path in [directory, *directory.rglob("*")]:
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise RuntimeError("refusing unsafe input fixture entry")
        result[path.relative_to(directory).as_posix()] = (
            "directory" if path.is_dir() else "file", path.stat().st_mode & 0o777,
            None if path.is_dir() else hashlib.sha256(path.read_bytes()).hexdigest())
    return result


def run_volume(engine, image, options, command, inputs, outputs, uid, gid, owners=None):
    """Run without daemon-host bind paths, retaining numeric output ownership."""
    original_inputs = fixture_contents(inputs)
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
               input=fixture_archive(inputs, outputs, uid, gid, owners))
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
        exported_inputs = invoke("cp", "--archive", runtime + ":/input", "-", text=False).stdout
        exported = invoke("cp", "--archive", runtime + ":/output", "-", text=False).stdout
        with tempfile.TemporaryDirectory(prefix="audio-utils-copyback-") as directory:
            input_snapshot = Path(directory) / "input"
            extract_snapshot(exported_inputs, input_snapshot, "input")
            if fixture_contents(input_snapshot) != original_inputs:
                raise RuntimeError("runtime changed the read-only input fixture")
            snapshot = Path(directory) / "output"
            exported_owners = extract_snapshot(exported, snapshot)
            # Replace the complete snapshot so deletions cannot be hidden by merging.
            shutil.rmtree(outputs)
            shutil.move(str(snapshot), str(outputs))
        result = subprocess.CompletedProcess([engine, "run", image, *map(str, command)],
                                             state["ExitCode"], started.stdout, started.stderr)
        result.fixture_owners = exported_owners
        return result
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
