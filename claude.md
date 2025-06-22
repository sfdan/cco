# Claudito - Secure Claude Code Container

A minimal, secure way to run Claude Code in a Docker container with proper authentication handling.

## Architecture

- **Base**: Node.js with modern shell tools (jq, fzf, ripgrep, git, etc.)
- **Security**: Dropped capabilities, read-only credential mounts, network restrictions
- **Auth**: Auto-detects macOS Keychain or Linux credential files
- **Tools**: Comprehensive dev toolchain including PostgreSQL and SQLite clients

## Design Principles

1. **Security First**: Container runs with minimal privileges
2. **Zero Config**: Works out of the box if Claude Code is authenticated
3. **Cross Platform**: macOS and Linux support
4. **Minimal**: Single script, single command to run

## Components

- `Dockerfile`: Based on Anthropic's devcontainer with enhanced tooling
- `claudito`: Main script that handles build/run logic
- Authentication auto-detection for both subscription and API key auth