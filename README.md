# godot-editor-console-mcp

A thin **Go MCP server** that drives the `Godot Editor Console` addon's command surface in the **live Godot editor**.

It exposes two MCP tools that forward to a small loopback TCP listener inside the editor:
- **`run_console_command`** — run any command line and return its output. Because it reuses
  the console's own execution path, the full surface works: commands, pipes (`|`),
  `&&`/`||`, `;`, and gdsh(bash-ish scripts).
- **`list_commands`** — list the available commands for discovery.

```
Claude Code ──stdio MCP──▶ godot-editor-console-mcp ──TCP 127.0.0.1:9510──▶ editor_console bridge ──▶ live editor
```

## How it works

1. The in-editor bridge (`addons/editor_console/src/bridge/console_bridge.gd`) listens on
   `127.0.0.1:<port>` and runs each request through `EditorConsoleSingleton.run_command_capture`.
2. This binary connects to that port — either as an MCP server (default) or a one-shot CLI.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/brohd11/Godot-Editor-Console-MCP/main/install.sh | sh
```

Installs to `~/.local/bin` and prints the `claude mcp add` line to run. Prefer to read
before you pipe to a shell? Same thing in two steps:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/brohd11/Godot-Editor-Console-MCP/main/install.sh
less install.sh && sh install.sh
```

Overrides: `BIN_DIR=/usr/local/bin` to install elsewhere, `VERSION=v0.1.0-beta` to pin a release.

Covers macOS (arm64/amd64) and Linux (amd64/arm64). On **Windows**, grab the `.zip` from the
[Releases](https://github.com/brohd11/Godot-Editor-Console-MCP/releases) page and unzip it.

## Build

```bash
make            # host build      -> build/<os>-<arch>/godot-editor-console-mcp
make all        # release targets -> build/{darwin,linux}-{amd64,arm64}/, windows-amd64/
make package    # build all, then archive each -> build/<binary>-<os>-<arch>.{tar.gz,zip}
make clean      # remove build/
```

Archive names are version-less on purpose, so `install.sh` can use GitHub's
`/releases/latest/download/<name>` redirect without an API call. Upload the
`build/` archives to the release as-is.

Builds are static (`CGO_ENABLED=0`) and stripped. The Windows target is `godot-editor-console-mcp.exe`.
The version is stamped in from the git tag (`git describe`); `godot-editor-console-mcp version`
prints it.

## Use

**Start the bridge in the editor** (once per session — it's off by default):

```
mcp bridge start          # listens on 127.0.0.1:9510
mcp bridge status
```
You can also add this to your startup commands in the Editor Console, see below.

**Register MCP server** (Claude Code):

```bash
claude mcp add -s user godot-editor-console -- ~/.local/bin/godot-editor-console-mcp
```

`-s user` registers it once for **every** directory on the machine. The scopes:

| Scope | Stored in | Available in |
|---|---|---|
| `local` (default) | `~/.claude.json`, keyed by project path | only the directory you ran it in |
| `user` | `~/.claude.json`, global | every project on the machine |
| `project` | `.mcp.json`, committed to the repo | anyone who clones the repo |

For `project` scope, put `~/.local/bin` on your `PATH` and register the bare command
(`-- godot-editor-console-mcp`) instead of an absolute path, so the entry isn't tied to
your home directory.

**macOS:** if you downloaded the archive **in a browser**, Gatekeeper quarantines the
unsigned binary — clear the flag once (or right-click → Open the first time):

```bash
xattr -d com.apple.quarantine godot-editor-console-mcp
```

This doesn't apply to `install.sh` or a plain `curl` download; the quarantine attribute is
set by browsers, not by curl.

Then ask Claude to use the `run_console_command` tool, e.g. *"run `scene edited tree | count`"*.

**Can also run via CLI** (talks to the same live editor, no headless boot):

```bash
./path/to/godot-editor-console-mcp run "scene edited tree --type=Sprite2D | count"
```

stdout goes to stdout, stderr to stderr, and the process exit code mirrors the command's.

## Auto-start the bridge each session

The bridge is off by default. To start it automatically when the editor loads, add a console
startup command:

```
config startup --add "mcp bridge start"
# or with a token / custom port:
config startup --add "mcp bridge start 9510 mytoken"
```

## Token auth (optional)

Start the bridge with a shared secret and give the same value to the client:

```
mcp bridge start 9510 mytoken          # in the console
```
```bash
claude mcp add godot-editor-console --env EDITOR_CONSOLE_TOKEN=mytoken -- /abs/path/to/godot-editor-console-mcp
# or for the CLI:
EDITOR_CONSOLE_TOKEN=mytoken ./path/to/godot-editor-console-mcp run "ls res://"
```
Requests with a missing/wrong token get an `Unauthorized` response.

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `EDITOR_CONSOLE_PORT` | `9510` | Bridge port (must match `mcp bridge start <port>`). |
| `EDITOR_CONSOLE_TOKEN` | _(none)_ | Shared secret; if set, must match the token the bridge was started with. |

For Claude Code, pass env in the MCP registration, e.g.:

```bash
claude mcp add godot-editor-console --env EDITOR_CONSOLE_PORT=9510 -- /abs/path/to/godot-editor-console-mcp
```

## Security

- The bridge binds **loopback only** and is **off by default** — you must run `mcp bridge start`.
- `run_console_command` is effectively remote control of your editor. Keep it local; do not
  expose the port. Use `EDITOR_CONSOLE_TOKEN` for a basic shared-secret check.

## Protocol (for reference)

Newline-delimited JSON over TCP:

```
→ {"id":1,"cmd":"scene edited tree | count","token":"optional"}\n
← {"id":1,"stdout":"...","stderr":"...","exit_code":0}\n
```
