# Locked audio development environments

Provide a reproducible devenv shell and source-free development images for Docker,
rootless Podman, and Apple container. Preserve every audio pipeline and public CLI
contract. Tests must use disposable fixtures with isolated HOME/XDG/TMPDIR, never
a real media library. Missing optional codecs must remain explicit skips.

Linux acceptance runs make check and all test tiers plus the Node MCP tests and
adapter regressions. Native macOS covers lint and adapter checks only: the product
targets GNU/Linux. Apple execution needs supported Mac hardware and a Linux Nix
builder and is not established by Linux adapter tests. Images must not include
checkout contents, credentials, or live media, and runs preserve caller ownership.
