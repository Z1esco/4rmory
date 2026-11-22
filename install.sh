#!/usr/bin/env bash
# Install 4rmory: links the 4rmory command into ~/.local/bin.
set -eu
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${PREFIX:-$HOME/.local/bin}"
mkdir -p "$bin"
chmod +x "$here/4rmory"
ln -sfn "$here/4rmory" "$bin/4rmory"
echo "✔ Installed: $bin/4rmory"
case ":$PATH:" in *":$bin:"*) ;; *) echo "! Add $bin to your PATH, e.g. echo 'export PATH=\"$bin:\$PATH\"' >> ~/.bashrc" ;; esac
echo "  Next: 4rmory doctor   then   4rmory setup"
