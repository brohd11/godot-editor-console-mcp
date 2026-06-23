package main

import (
	"context"
	"fmt"
	"log"
	"os"
)

func defaultAddr() string {
	port := os.Getenv("EDITOR_CONSOLE_PORT")
	if port == "" {
		port = "9510"
	}
	return "127.0.0.1:" + port
}

func main() {
	addr := defaultAddr()
	token := os.Getenv("EDITOR_CONSOLE_TOKEN")

	// One-shot CLI mode: `editor-console-mcp run "<command>"`.
	if len(os.Args) > 1 && os.Args[1] == "run" {
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, `usage: editor-console-mcp run "<command>"`)
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

	// Default: run as an MCP server over stdio.
	if err := serve(context.Background(), addr, token); err != nil {
		log.Fatal(err)
	}
}
