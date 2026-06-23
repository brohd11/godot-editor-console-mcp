#!/usr/bin/env bash
set -euo pipefail

# Architecture to register; override with `ARCH=amd64 ./add_mcp.sh`. Defaults to arm64.
ARCH="${ARCH:-arm64}"

# OS from uname, lowercased to match the build/<os>-<arch>/ layout (darwin|linux).
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# Resolve paths relative to this script so it works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="editor-console"
BIN="$SCRIPT_DIR/build/$OS-$ARCH/editor-console-mcp"

if [[ ! -x "$BIN" ]]; then
  echo "Binary not found: $BIN" >&2
  echo "Build it first:  make all   (or: ARCH=$ARCH make $OS/$ARCH)" >&2
  exit 1
fi

# Re-register cleanly (ignore if it wasn't registered yet).
claude mcp remove "$NAME" 2>/dev/null || true
claude mcp add "$NAME" -- "$BIN"

echo "Registered MCP '$NAME' -> $BIN"
