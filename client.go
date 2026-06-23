package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"time"
)

type request struct {
	ID    int    `json:"id"`
	Cmd   string `json:"cmd"`
	Token string `json:"token,omitempty"`
}

type response struct {
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
	// Godot's JSON.parse coerces all numbers to float, so any number echoed back
	// (and exit_code) can arrive as e.g. 0.0 — decode as float and convert.
	ExitCode float64 `json:"exit_code"`
}

// runCommand sends a single command to the in-editor bridge and returns its response.
func runCommand(addr, token, cmd string) (response, error) {
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return response{}, fmt.Errorf("could not connect to the Godot bridge at %s: %w\n"+
			"(open the editor with the editor_console addon enabled and run 'dev bridge start')", addr, err)
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(120 * time.Second))

	payload, err := json.Marshal(request{ID: 1, Cmd: cmd, Token: token})
	if err != nil {
		return response{}, err
	}
	payload = append(payload, '\n')
	if _, err := conn.Write(payload); err != nil {
		return response{}, fmt.Errorf("write to bridge failed: %w", err)
	}

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil && len(line) == 0 {
		return response{}, fmt.Errorf("read from bridge failed: %w", err)
	}

	var resp response
	if err := json.Unmarshal(line, &resp); err != nil {
		return response{}, fmt.Errorf("invalid response from bridge: %w", err)
	}
	return resp, nil
}
