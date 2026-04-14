# npm Binary Distribution of Clash

## Summary

Two npm packages that distribute clash to the JS/TS agent ecosystem. `@empathic/clash` is a platform-aware binary distribution — the same binary that `install.sh` and `cargo install` provide, but delivered via npm. `@empathic/clash-pi` is a Pi agent extension package that depends on `@empathic/clash` and provides the `tool_call` hook integration.

## Motivation

Pi is a TypeScript-based AI coding agent framework with a native package system (`pi install npm:<pkg>`). Distributing clash via npm lets Pi users install clash and the Pi extension in one command, using the conventions they already know. The binary distribution package also serves as the foundation for any future JS/TS agent framework integrations.

## Package Structure

### `@empathic/clash` (binary distribution)

```
clash-npm/
  package.json          # "bin": { "clash": "bin/clash" }, optionalDependencies
  scripts/
    postinstall.js      # copies binary from platform package into bin/
  bin/
    .gitkeep            # placeholder, populated at install time
```

The main package contains no binary itself. It declares `optionalDependencies` on three platform packages. npm's resolution installs only the matching one.

`postinstall.js` locates the installed platform package, copies the binary to `bin/clash`, and sets it executable. This is the same pattern `esbuild`, `turbo`, and `biome` use.

### Platform packages

One per supported target, each containing just the binary and a minimal `package.json` with `os` and `cpu` fields:

| Clash target | npm package | `os` | `cpu` |
|---|---|---|---|
| `aarch64-apple-darwin` | `@empathic/clash-darwin-arm64` | `darwin` | `arm64` |
| `x86_64-unknown-linux-musl` | `@empathic/clash-linux-x64` | `linux` | `x64` |
| `aarch64-unknown-linux-gnu` | `@empathic/clash-linux-arm64` | `linux` | `arm64` |

Intel Mac and Windows are not supported (same as today).

### `@empathic/clash-pi` (Pi extension)

```
clash-pi/
  package.json          # depends on @empathic/clash, declares pi package layout
  extensions/
    clash.ts            # tool_call hook -> clash hook --agent opencode pre-tool-use
```

Installed via `pi install npm:@empathic/clash-pi`. Pi auto-discovers the extension from the conventional `extensions/` directory in installed packages.

## Pi Extension Behavior

The extension registers three hooks:

### `session_start`

Calls `clash hook --agent opencode session-start` with session metadata on stdin. If clash isn't found on PATH (binary resolution fails), sets a `clashMissing` flag and logs a loud warning. Does not block the session.

### `tool_call`

The primary enforcement point. Fires before every tool execution.

- If `clashMissing` is set: logs a one-time visible warning on the first tool call ("clash binary not found — all tool calls are unprotected"), then allows everything (fail open).
- Otherwise: spawns `clash hook --agent opencode pre-tool-use` with the tool event as JSON on stdin. Reads the JSON response:
  - `{ "action": "allow" }` — passes through, tool executes normally
  - `{ "action": "allow", "args": {...} }` — sandbox rewrite, mutates the tool input args before execution
  - `{ "action": "deny", "reason": "..." }` — returns `{ block: true, reason }` to Pi, blocking the tool call
  - `{ "action": "ask" }` — if `ctx.hasUI`, prompts the user via `ctx.ui.select()`; otherwise falls through to allow

If the clash process fails (crash, timeout), the extension logs the error and allows the tool call (fail open). The 10-second timeout matches the existing OpenCode plugin behavior.

### `tool_result`

Calls `clash hook --agent opencode post-tool-use` for audit logging. Advisory and non-blocking — errors are swallowed.

## Protocol

Uses `--agent opencode` since Pi's tool names and JSON shape are compatible with the OpenCode protocol:

| Pi tool | OpenCode equivalent | Clash internal |
|---|---|---|
| `bash` | `bash` | `Bash` |
| `read` | `read` | `Read` |
| `write` | `write` | `Write` |
| `edit` | `edit` | `Edit` |
| `grep` | `grep` | `Grep` |
| `find` | — | passthrough |
| `ls` | — | passthrough |

A follow-up adds proper `AgentKind::Pi` with Pi-specific tool name mappings and any protocol differences that emerge from real usage.

## Release Integration

The existing release CI builds binaries for 3 targets and publishes them to GitHub Releases. A new `npm-publish` job runs after the GitHub Release is created:

1. Downloads the 3 binary tarball artifacts from the GitHub Release
2. Extracts each binary into its platform npm package directory
3. Publishes all 5 packages in order: 3 platform packages, then `@empathic/clash`, then `@empathic/clash-pi`

Version numbers mirror the clash version (currently `0.6.2`). The workflow uses `NPM_TOKEN` from repository secrets for authentication.

## User Install Flow

```bash
# Pi users (installs binary + extension):
pi install npm:@empathic/clash-pi

# General npm users (just the binary):
npm install -g @empathic/clash

# Existing install methods continue to work:
curl -fsSL https://raw.githubusercontent.com/empathic/clash/main/install.sh | sh
cargo install clash
```

## File Layout in Repo

```
clash-npm/                              # @empathic/clash main package
  package.json
  scripts/postinstall.js
  bin/.gitkeep

clash-npm/platforms/darwin-arm64/       # @empathic/clash-darwin-arm64
  package.json

clash-npm/platforms/linux-x64/          # @empathic/clash-linux-x64
  package.json

clash-npm/platforms/linux-arm64/        # @empathic/clash-linux-arm64
  package.json

clash-pi/                               # @empathic/clash-pi
  package.json
  extensions/clash.ts
```

## Out of Scope

- `AgentKind::Pi` in Rust (follow-up)
- `clash init --agent pi` (follow-up)
- Intel Mac / Windows platform packages
- napi-rs native module (not needed — subprocess latency is negligible for per-tool-call evaluation)
