# editor-console-mcp

A thin **Go MCP server + CLI** that drives the `editor_console` addon's command surface
(`dev` commands, pipes, gdsh) in the **live Godot editor**.

It exposes two MCP tools that forward to a small loopback TCP listener inside the editor:
- **`run_console_command`** — run any command line and return its output. Because it reuses
  the console's own execution path, the full surface works: `dev` commands, pipes (`|`),
  `&&`/`||`, `;`, and gdsh.
- **`list_commands`** — list the available `dev` commands (runs `dev --help`) for discovery.

```
Claude Code ──stdio MCP──▶ editor-console-mcp ──TCP 127.0.0.1:9510──▶ editor_console bridge ──▶ live editor
```

## How it works

1. The in-editor bridge (`addons/editor_console/src/bridge/console_bridge.gd`) listens on
   `127.0.0.1:<port>` and runs each request through `EditorConsoleSingleton.run_command_capture`.
2. This binary connects to that port — either as an MCP server (default) or a one-shot CLI.

## Build

```bash
make            # host build  -> build/<os>-<arch>/editor-console-mcp
make all        # all targets -> build/{darwin-arm64,darwin-amd64,linux-amd64,linux-arm64,windows-amd64}/
make clean      # remove build/
```

Builds are static (`CGO_ENABLED=0`) and stripped. The Windows target is `editor-console-mcp.exe`.

## Use

**1. Start the bridge in the editor** (once per session — it's off by default):

```
dev bridge start          # listens on 127.0.0.1:9510
dev bridge status
```

**2a. As an MCP server** — register with Claude Code:

```bash
claude mcp add editor-console -- /abs/path/to/build/<os>-<arch>/editor-console-mcp
```

Then ask Claude to use the `run_console_command` tool, e.g. *"run `dev tree | dev count`"*.

**2b. As a CLI** (talks to the same live editor, no headless boot):

```bash
./build/<os>-<arch>/editor-console-mcp run "dev tree --type=Sprite2D | dev count"
```

stdout goes to stdout, stderr to stderr, and the process exit code mirrors the command's.

## Auto-start the bridge each session

The bridge is off by default. To start it automatically when the editor loads, add a console
startup command (reuses the addon's existing startup mechanism):

```
config startup --add "dev bridge start"
# or with a token / custom port:
config startup --add "dev bridge start 9510 mytoken"
```

## Token auth (optional)

Start the bridge with a shared secret and give the same value to the client:

```
dev bridge start 9510 mytoken          # in the console
```
```bash
claude mcp add editor-console --env EDITOR_CONSOLE_TOKEN=mytoken -- /abs/path/to/build/<os>-<arch>/editor-console-mcp
# or for the CLI:
EDITOR_CONSOLE_TOKEN=mytoken ./build/<os>-<arch>/editor-console-mcp run "dev ls res://"
```
Requests with a missing/wrong token get an `Unauthorized` response.

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `EDITOR_CONSOLE_PORT` | `9510` | Bridge port (must match `dev bridge start <port>`). |
| `EDITOR_CONSOLE_TOKEN` | _(none)_ | Shared secret; if set, must match the token the bridge was started with. |

For Claude Code, pass env in the MCP registration, e.g.:

```bash
claude mcp add editor-console --env EDITOR_CONSOLE_PORT=9510 -- /abs/path/to/build/<os>-<arch>/editor-console-mcp
```

## Security

- The bridge binds **loopback only** and is **off by default** — you must run `dev bridge start`.
- `run_console_command` is effectively remote control of your editor. Keep it local; do not
  expose the port. Use `EDITOR_CONSOLE_TOKEN` for a basic shared-secret check.

## Protocol (for reference)

Newline-delimited JSON over TCP:

```
→ {"id":1,"cmd":"dev tree | dev count","token":"optional"}\n
← {"id":1,"stdout":"...","stderr":"...","exit_code":0}\n
```
