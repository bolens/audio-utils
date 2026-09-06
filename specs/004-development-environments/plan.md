# Implementation plan

Pin devenv/nixpkgs inputs and supply Bash, GNU tools, Python, Node, ShellCheck,
FFmpeg, FLAC, and available preservation utilities. Wrap native Make gates and
locked npm installation in one failure-propagating check. Reuse the tested engine
adapter with repository-specific image identity and argument regression tests.

Use filtered Linux/macOS CI with real Docker validation on Linux and an always
reporting result gate. Existing sharded runtime and release checks remain required.
Validate native and Podman paths before the PR; protected merge and published
runtime digest verification follow RELEASING.md. No VERSION change is needed.
