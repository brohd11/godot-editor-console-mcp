# godot-editor-console-mcp

Go MCP server for `Godot Editor Console` addon.

It exposes two MCP tools that forward to a loopback TCP listener inside the editor:
- **`run_console_command`** — run commands and return the output. 
- **`list_commands`** — list the available commands for discovery.

The Editor Console addon uses a bash-like syntax ([gdsh library](https://github.com/brohd11/godot-gdsh.git)), allowing for multiline execution, pipes, conditionals. So the agent can compose the listed commands freely.


## How it works

1. The in-editor bridge (`addons/editor_console/src/bridge/console_bridge.gd`) listens on
   `127.0.0.1:<port>` and runs each request through `EditorConsoleSingleton.run_command_capture`.
2. This binary connects to that port, either as an MCP server (default) or a one-shot CLI.

## Install

Install to `~/.local/bin` on all platforms.

Linux, Mac:
```bash
curl -fsSL https://raw.githubusercontent.com/brohd11/godot-editor-console-mcp/main/install.sh | sh
```

Windows:
```powershell
irm https://raw.githubusercontent.com/brohd11/godot-editor-console-mcp/main/install.ps1 | iex
```

More install details (location, flags, etc): [shared install reference](https://github.com/brohd11/goutil/blob/main/docs/install.md).

**macOS note:** a binary downloaded **in a browser** gets quarantined by Gatekeeper. Clear it
with `xattr -dr com.apple.quarantine path/to/binary`. This doesn't apply to the installer
above; the attribute is set by browsers, not by `curl`.

## Update

Check for a newer release or install it over the running binary:

```sh
godot-editor-console-mcp update --check
godot-editor-console-mcp update
```
## Use

Run `godot-editor-console-mcp --help` for CLI usage and environment options.

Start the bridge in the editor (once per session, it's off by default):

```sh
mcp bridge start          # listens on 127.0.0.1:9510
mcp bridge status
```
You can also add this to your startup commands in the Editor Console.

``` sh
config startup --add "mcp bridge start"
# or with a token / custom port:
config startup --add "mcp bridge start 9510 mytoken"
```

Register MCP server in the Editor Console:
```sh
mcp add claude
mcp add kimi
```
Or do it in the terminal:
```sh
claude mcp add -s user godot-editor-console -- ~/.local/bin/godot-editor-console-mcp
```

Then ask Claude to use the `run_console_command` tool, e.g. `run scene edited tree | count`

**Can also run via CLI** (talks to the same live editor, no headless boot):

```bash
./path/to/godot-editor-console-mcp run "scene edited tree --type=Sprite2D | count"
```

stdout goes to stdout, stderr to stderr, and the process exit code mirrors the command's.

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

Pass env in the MCP registration:
```bash
claude mcp add godot-editor-console --env EDITOR_CONSOLE_PORT=9510 -- /abs/path/to/godot-editor-console-mcp
```

## Security

- The bridge binds loopback only and is off by default — you must run `mcp bridge start`.
- `run_console_command` is effectively remote control of your editor. Keep it local; do not
  expose the port. Use `EDITOR_CONSOLE_TOKEN` for a basic shared-secret check.

## Protocol (for reference)

Newline-delimited JSON over TCP:

```json
→ {"id":1,"cmd":"scene edited tree | count","token":"optional"}\n
← {"id":1,"stdout":"...","stderr":"...","exit_code":0}\n
```
