#!/usr/bin/env bash
# Stamp the shared installer bodies into this repo's install.sh and install.ps1.
#
#   ./render-installers.sh           rewrite each installer, report updated/unchanged
#   ./render-installers.sh --check   verify they match; exit 1 on drift
#
# --check is what you want in a pre-tag gate: it fails if an installer was edited
# directly instead of editing the shared template.
#
# The stamping itself lives in the pinned sh-templates submodule.
# This entry script selects the targets and checks their syntax.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 1

STAMPER="$ROOT/sh-templates/go/render-installer.sh"
COMMON_STAMPER="$ROOT/sh-templates/common/stamp-template.sh"

TARGETS=(
  "install.sh"
  "install.ps1"
)

case "${1:-}" in
  --check|"") ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

for renderer in "$STAMPER" "$COMMON_STAMPER"; do
  if [[ ! -x "$renderer" ]]; then
    echo "$(basename "$0"): required submodule renderer not found: $renderer" >&2
    echo "Initialize it with: git submodule update --init sh-templates" >&2
    exit 1
  fi
done

check_powershell() {
  INSTALLER_PARSE_PATH="$1" pwsh -NoProfile -NonInteractive -Command '
    $ErrorActionPreference = "Stop"
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path -LiteralPath $env:INSTALLER_PARSE_PATH).Path,
      [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
      $parseErrors | ForEach-Object { [Console]::Error.WriteLine($_.ToString()) }
      exit 1
    }
  '
}

# The pinned Go renderer passes PowerShell arguments using -Command ... -args,
# which does not populate $args when called from Bash. Use the same common stamper
# for PS1 and pass the parser's path through the environment until that is fixed.
render_powershell() {
  local target=$1
  shift
  local template="$ROOT/sh-templates/go/install.template.ps1"
  if command -v pwsh >/dev/null 2>&1; then
    check_powershell "$template" || return 1
  else
    echo "  $target syntax unchecked: no pwsh"
  fi
  printf '  %s ' "$target"
  "$COMMON_STAMPER" "$@" "$template" "$target" "$target" || return 1
  if command -v pwsh >/dev/null 2>&1; then
    check_powershell "$target" || return 1
  fi
}

# Rendering is in place: the target supplies its own config block and receives the
# result, so IN and OUT are the same path. Accumulate failure so --check can gate a
# preflight -- a single drifted or broken target must fail the whole run.
fail=0
for t in "${TARGETS[@]}"; do
  case "$t" in
    *.ps1) render_powershell "$t" "$@" || fail=1 ;;
    *)
      "$STAMPER" "$@" "$t" || fail=1
      sh -n "$t" || fail=1
      ;;
  esac
done

exit "$fail"
