package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/brohd11/goutil/selfupdate"
)

// version is set at build time via -ldflags "-X main.version=...". See the Makefile.
var version = "dev"

const helpText = `Godot Editor Console MCP server and command-line client.

Usage:
  godot-editor-console-mcp                   Start the MCP server over stdio
  godot-editor-console-mcp run "<command>"   Run a command in the live Godot editor
  godot-editor-console-mcp update [--check]   Install an update, or only check for one

Options:
  -h, --help      Show this help
  --version      Print the binary version

Environment:
  EDITOR_CONSOLE_PORT    Editor bridge port (default: 9510)
  EDITOR_CONSOLE_TOKEN   Shared secret for the editor bridge (optional)

The editor bridge must be running for editor commands to work.
Use "godot-editor-console-mcp update --help" for update details.
`

func defaultAddr() string {
	port := os.Getenv("EDITOR_CONSOLE_PORT")
	if port == "" {
		port = "9510"
	}
	return "127.0.0.1:" + port
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "--help" || os.Args[1] == "-h") {
		fmt.Print(helpText)
		return
	}

	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(version)
		return
	}

	if len(os.Args) > 1 && os.Args[1] == "update" {
		cmd := selfupdate.NewUpdateCommand("brohd11/godot-editor-console-mcp", "godot-editor-console-mcp", version)
		cmd.SetArgs(os.Args[2:])
		if err := cmd.Execute(); err != nil {
			os.Exit(1)
		}
		return
	}

	addr := defaultAddr()
	token := os.Getenv("EDITOR_CONSOLE_TOKEN")

	// One-shot CLI mode: godot-editor-console-mcp run "<command>"`.
	if len(os.Args) > 1 && os.Args[1] == "run" {
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, `usage: godot-editor-console-mcp run "<command>"`)
			os.Exit(2)
		}
		resp, err := runCommand(addr, token, os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if resp.Stdout != "" {
			fmt.Println(resp.Stdout)
		}
		if resp.Stderr != "" {
			fmt.Fprintln(os.Stderr, resp.Stderr)
		}
		os.Exit(int(resp.ExitCode))
	}

	if len(os.Args) > 1 {
		fmt.Fprintf(os.Stderr, "unknown command or option: %q\nRun godot-editor-console-mcp --help for usage.\n", os.Args[1])
		os.Exit(2)
	}

	// With no arguments, run as an MCP server over stdio.
	if err := serve(context.Background(), addr, token); err != nil {
		log.Fatal(err)
	}
}
