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

## Build

```bash
make            # host build      -> build/<os>-<arch>/godot-editor-console-mcp
make all        # release targets -> build/{darwin-arm64,linux-amd64,windows-amd64}/
make package    # build all, then zip each -> build/<binary>-<version>-<os>-<arch>.zip
make clean      # remove build/
```

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
claude mcp add godot-editor-console -- /abs/path/to/build/godot-editor-console-mcp
```

Grab the zip for your OS/arch from the **Releases** page, unzip it (you get a single
`godot-editor-console-mcp` executable — `.exe` on Windows), then point Claude Code at it:

```bash
chmod +x godot-editor-console-mcp                                    # macOS / Linux
claude mcp add godot-editor-console -- /abs/path/to/godot-editor-console-mcp
```

**macOS:** a downloaded binary is unsigned, so Gatekeeper quarantines it. Clear the flag
once (or right-click → Open the first time):

```bash
xattr -d com.apple.quarantine godot-editor-console-mcp
```

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
