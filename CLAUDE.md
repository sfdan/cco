# ccon - A Thin Protective Layer for Claude

A minimal, secure way to run Claude Code in a Docker container with proper authentication handling.

## Architecture

- **Base**: Node.js with modern shell tools (jq, fzf, ripgrep, git, etc.)
- **Security**: Dropped capabilities, read-only credential mounts, network restrictions
- **Auth**: Auto-detects macOS Keychain or Linux credential files
- **Tools**: Comprehensive dev toolchain including PostgreSQL and SQLite clients
- **Config Detection**: Supports CLAUDE_CONFIG_DIR, XDG_CONFIG_HOME, and ~/.claude fallback

## Design Principles

1. **Security First**: Container runs with minimal privileges
2. **Zero Config**: Works out of the box if Claude Code is authenticated
3. **Cross Platform**: macOS and Linux support
4. **Minimal**: Single script, single command to run

## Components

- `Dockerfile`: Based on Anthropic's devcontainer with enhanced tooling
- `ccon`: Main script that handles build/run logic
- Authentication auto-detection for both subscription and API key auth

## Testing and Debugging

**IMPORTANT**: Claude Code cannot run interactive bash sessions inside containers due to tool limitations.

### Testing Container Environment
```bash
# Run one-off commands inside container
./ccon --shell 'env | grep CLAUDE'

# Test Claude Code non-interactively
./ccon "what is 2+2?"

# Debug configuration
./ccon --shell "ls -la ~/.claude"
```

### Development Sanity Check Suite

Before committing major changes, always run this test suite:

```bash
# 1. Basic functionality
./ccon "what is 2+2?"

# 2. Shell mode
./ccon --shell whoami
./ccon --shell 'echo "HOME: $HOME" && id && pwd'

# 3. UV/Python environment
./ccon --shell 'uv --version'
./ccon --shell 'cd /tmp && uv init test-sanity && cd test-sanity && ls -la'

# 4. Claude Code integration
./ccon "create a simple Python project with uv"

# 5. Rebuild capability
./ccon --rebuild
```

**Success criteria**: No permission errors, no authentication prompts, no hanging, proper user identity and environment.

### DO NOT attempt:
- Interactive shells expecting responses
- Commands that require stdin input
- Multi-step interactive debugging sessions

## Claude Code Configuration Hierarchy

**CRITICAL**: Claude Code uses a hierarchical configuration system that must be preserved to prevent data corruption.

### System vs Project Configuration

#### System Configuration (Global)
- **Location**: Determined by priority order:
  1. `$CLAUDE_CONFIG_DIR` environment variable
  2. `$XDG_CONFIG_HOME/claude` or `~/.config/claude` (v1.0.30+)
  3. `~/.claude` (legacy fallback)
- **Contains**: 
  - Credentials (`.credentials.json`)
  - Global settings (`settings.json`)
  - User commands, projects, todos
  - OAuth account information
- **Container Mount**: Read-only to `/home/user/.claude`
- **Purpose**: User-wide authentication and preferences

#### Project Configuration (Local)
- **Location**: `$PROJECT_DIR/.claude/`
- **Contains**:
  - Project-specific settings (`settings.json`, `settings.local.json`)
  - Local commands and tools
  - Project-specific todos and state
- **Container Mount**: Read-write to `$PROJECT_DIR/.claude`
- **Purpose**: Project-specific overrides and settings

### Security Architecture

#### Credentials Protection
- **Never baked into Docker images**: Credentials are verified but not copied during build
- **Runtime mounting only**: Fresh credentials extracted from Keychain/files at container start
- **Read-only mounts**: System config mounted read-only to prevent accidental modification
- **Temporary extraction**: Keychain credentials written to temp files, cleaned up on exit

#### Mount Strategy
```bash
# System config (read-only)
host:~/.claude → container:/home/user/.claude:ro

# Project config (read-write) 
host:$PROJECT/.claude → container:$PROJECT/.claude:rw

# Fresh credentials (read-only)
host:/tmp/ccon-creds-$$ → container:/home/user/.claude/.credentials.json:ro
```

### Environment Variables

#### Passed Through to Container
- `CLAUDE_CONFIG_DIR`: Override system config location
- `XDG_CONFIG_HOME`: XDG Base Directory specification
- `ANTHROPIC_API_KEY`: API authentication (alternative to OAuth)
- Standard environment: `NO_COLOR`, `TERM`, proxy settings, git config

#### Set by Claudito
- `CLAUDE_CONFIG_DIR=/home/user/.claude`: Forces container to use mounted system config

### Data Corruption Prevention

#### What Claudito Does RIGHT
- ✅ Copies system config to `.claude-system/` staging area (not `.claude/`)
- ✅ Mounts system config read-only
- ✅ Preserves project `.claude/` directories untouched
- ✅ Never bakes credentials into Docker images
- ✅ Maintains clear separation between system and project config

#### What Would Be DANGEROUS
- ❌ Copying system config into project `.claude/` directory
- ❌ Mounting project config to system location in container
- ❌ Baking credentials into Docker images
- ❌ Read-write mounting of system config
- ❌ Mixing system and project configuration files