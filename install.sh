#!/bin/sh
# Install the godot-editor-console MCP server into ~/.local/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/brohd11/Godot-Editor-Console-MCP/main/install.sh | sh
#
# Env overrides:
#   BIN_DIR=/usr/local/bin   install target   (default: ~/.local/bin)
#   VERSION=v0.1.0-beta      pin a release    (default: latest)
#   --no-modify-path         never touch shell rc files
#
# Body below "end config" is shared with ~/main/go/install.template.sh -- to update,
# chop at that line and paste the current template body.

set -eu

# ---- config ----
REPO="brohd11/Godot-Editor-Console-MCP"
BINARY="godot-editor-console-mcp"
ARCHIVE_EXT="tar.gz"
SUPPORTED="darwin-arm64 darwin-amd64 linux-amd64 linux-arm64"

# Printed after a successful install. Leave the body as ':' for nothing.
post_install_note() {
  cat <<EOF
Register with Claude Code (-s user makes it available in every directory;
drop the flag to scope it to just the current project):

  claude mcp add -s user godot-editor-console -- $BIN_DIR/$BINARY

Then, in the Godot editor console, start the bridge:

  mcp bridge start
EOF
}
# ---- end config ----

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
VERSION="${VERSION:-latest}"
MODIFY_PATH=1

for arg in "$@"; do
  case "$arg" in
    --no-modify-path) MODIFY_PATH=0 ;;
    -h|--help)
      # Not derived from $0: under `curl | sh` there is no script path to read.
      cat <<EOF
install $BINARY into \$BIN_DIR (default: \$HOME/.local/bin)

  BIN_DIR=<dir>       install target
  VERSION=<tag>       pin a release (default: latest)
  --no-modify-path    never touch shell rc files
EOF
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- detect platform ---------------------------------------------------------

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)

case "$arch" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) die "unsupported architecture: $arch" ;;
esac

case "$os" in
  darwin|linux) ;;
  *) die "unsupported OS: $os (Windows: download the .zip from https://github.com/$REPO/releases)" ;;
esac

target="$os-$arch"

# Word-match against SUPPORTED so a missing build fails here with a useful message
# rather than as a 404 later.
case " $SUPPORTED " in
  *" $target "*) ;;
  *) die "no $target build is published for $BINARY
  supported: $SUPPORTED
  build from source: https://github.com/$REPO" ;;
esac

asset="$BINARY-$target.$ARCHIVE_EXT"

# --- resolve URL -------------------------------------------------------------

# Asset names are deliberately version-less so the /latest/download redirect works
# and we never touch the GitHub API (no JSON parsing, no rate limit).
if [ "$VERSION" = latest ]; then
  url="https://github.com/$REPO/releases/latest/download/$asset"
else
  url="https://github.com/$REPO/releases/download/$VERSION/$asset"
fi

have curl || die "curl is required"
case "$ARCHIVE_EXT" in
  zip) have unzip || die "unzip is required to install $BINARY" ;;
  tar.gz) have tar || die "tar is required" ;;
  *) die "bad ARCHIVE_EXT in this script: $ARCHIVE_EXT" ;;
esac

# --- install -----------------------------------------------------------------

mkdir -p "$BIN_DIR" || die "cannot create $BIN_DIR"
[ -w "$BIN_DIR" ] || die "$BIN_DIR is not writable (set BIN_DIR to somewhere you own)"

echo "downloading $BINARY ($target, $VERSION)"

# Stage in a temp dir so a failed download can't leave a half-written binary in
# place of a working one.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

# Download and extract as separate steps rather than piping curl into the
# extractor: in a POSIX pipeline only the last command's status is visible, and
# both tar and unzip can exit 0 on empty input, so a 404 from curl would surface
# as a bogus "bad archive" error.
curl -fsSL -o "$tmp/$asset" "$url" \
  || die "download failed: $url
  (check https://github.com/$REPO/releases for available versions)"

case "$ARCHIVE_EXT" in
  zip) unzip -q -o "$tmp/$asset" -d "$tmp" || die "could not extract $asset" ;;
  tar.gz) tar -xzf "$tmp/$asset" -C "$tmp" || die "could not extract $asset" ;;
esac

[ -f "$tmp/$BINARY" ] || die "archive did not contain $BINARY"

chmod +x "$tmp/$BINARY"
mv -f "$tmp/$BINARY" "$BIN_DIR/$BINARY"

installed="$BIN_DIR/$BINARY"
echo "installed -> $installed"

# --- PATH --------------------------------------------------------------------

export_line="export PATH=\"\$PATH:$BIN_DIR\""
marker="# added by $BINARY installer"

rc_file() {
  case "$(basename "${SHELL:-}")" in
    zsh) echo "$HOME/.zshrc" ;;
    bash)
      # macOS terminals start login shells, which read .bash_profile, not .bashrc.
      if [ "$os" = darwin ]; then echo "$HOME/.bash_profile"; else echo "$HOME/.bashrc"; fi ;;
    *) echo "" ;;
  esac
}

add_to_path() {
  rc=$1
  if [ -f "$rc" ] && grep -qF "$marker" "$rc"; then
    echo "already configured in $rc"
    return
  fi

  printf '\n%s\n%s\n' "$marker" "$export_line" >> "$rc" || die "could not write to $rc"
  echo "added to $rc -- open a new shell, or run this in the current one:"
  echo "  $export_line"
}

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "$BIN_DIR is not on your PATH, so '$BINARY' won't be runnable by name."
    # Read from the terminal, not stdin: under `curl | sh` stdin is the script
    # itself, so a bare `read` would silently consume the remaining source.
    #
    # Probe by actually opening /dev/tty rather than testing -e/-r. The device node
    # can exist and look readable while open(2) still fails with ENXIO ("Device not
    # configured") when the process has no controlling terminal -- which is the norm
    # in CI and under some agent/daemon runners. Testing first avoids printing a
    # prompt we can't answer, and keeps the open error off the user's screen.
    #
    # The probe must run in a subshell, NOT as `exec 3</dev/tty`. exec is a POSIX
    # special builtin, so a failed redirection on it terminates a non-interactive
    # shell outright -- dash exits 2 and skips everything below, while bash and zsh
    # carry on. dash is /bin/sh on Debian and Ubuntu, so the exec form breaks exactly
    # the audience this installer targets. A subshell confines the failure.
    # Resolve the rc file up front: with no known one there is nothing to offer,
    # so print the line rather than prompting and then refusing the answer.
    rc=$(rc_file)
    if [ "$MODIFY_PATH" -eq 0 ] || [ -z "$rc" ]; then
      echo "add it with:"
      echo "  $export_line"
    elif (: < /dev/tty) 2>/dev/null; then
      printf 'Add it to %s? [y/N] ' "$rc"
      reply=""
      # `read` is not a special builtin, so a redirection failure here fails only
      # the command, and the || keeps us going.
      read -r reply < /dev/tty || reply=""
      case "$reply" in
        [yY]|[yY][eE][sS]) add_to_path "$rc" ;;
        *) echo "skipped. add it yourself with:"; echo "  $export_line" ;;
      esac
    else
      # Non-interactive (CI, piped with no tty): never edit dotfiles unasked.
      echo "add it with:"
      echo "  $export_line"
    fi
    ;;
esac

echo
post_install_note
