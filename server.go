package main

import (
	"context"
	"fmt"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

type runInput struct {
	Command string `json:"command"`
}

// serve runs the MCP server over stdio, exposing a single tool that forwards a
// command line to the in-editor bridge.
func serve(ctx context.Context, addr, token string) error {
	server := mcp.NewServer(&mcp.Implementation{
		Name:    "editor-console",
		Version: "0.1.0",
	}, nil)

	mcp.AddTool(server, &mcp.Tool{
		Name: "run_console_command",
		Description: "Run an editor_console command line in the live Godot editor and return its output. " +
			"Supports the full console surface: 'dev' commands, pipes (|), '&&'/'||', ';', and gdsh scripts. " +
			"Example: 'dev tree --type=Sprite2D | dev count'. Requires the editor open with the addon enabled " +
			"and 'dev bridge start' run once.",
	}, func(ctx context.Context, req *mcp.CallToolRequest, in runInput) (*mcp.CallToolResult, any, error) {
		resp, err := runCommand(addr, token, in.Command)
		if err != nil {
			return &mcp.CallToolResult{
				IsError: true,
				Content: []mcp.Content{&mcp.TextContent{Text: err.Error()}},
			}, nil, nil
		}

		text := resp.Stdout
		if resp.Stderr != "" {
			if text != "" {
				text += "\n"
			}
			text += "[stderr]\n" + resp.Stderr
		}
		if text == "" {
			text = fmt.Sprintf("(no output, exit_code=%d)", int(resp.ExitCode))
		}

		return &mcp.CallToolResult{
			IsError: resp.ExitCode != 0,
			Content: []mcp.Content{&mcp.TextContent{Text: text}},
		}, nil, nil
	})

	mcp.AddTool(server, &mcp.Tool{
		Name: "list_commands",
		Description: "List the available editor_console 'dev' commands (runs 'dev --help'). " +
			"Use this to discover the command surface before calling run_console_command.",
	}, func(ctx context.Context, req *mcp.CallToolRequest, _ struct{}) (*mcp.CallToolResult, any, error) {
		resp, err := runCommand(addr, token, "dev --help")
		if err != nil {
			return &mcp.CallToolResult{
				IsError: true,
				Content: []mcp.Content{&mcp.TextContent{Text: err.Error()}},
			}, nil, nil
		}
		text := resp.Stdout
		if resp.Stderr != "" {
			text += resp.Stderr
		}
		return &mcp.CallToolResult{
			Content: []mcp.Content{&mcp.TextContent{Text: text}},
		}, nil, nil
	})

	return server.Run(ctx, &mcp.StdioTransport{})
}
