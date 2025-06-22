# Claudito

A minimal, secure way to run Claude Code in a Docker container with proper authentication handling.

## Why Claudito?

Claude Code is fantastic but sometimes you want to run it in isolation - for security, for clean environments, or for CI/CD. Claudito gives you a secure containerized Claude Code that:

- **Just Works™**: Automatically inherits your Claude Code authentication
- **Secure by Default**: Runs with minimal privileges and network restrictions  
- **Zero Config**: Works out of the box if Claude Code is authenticated
- **Cross Platform**: macOS and Linux support

## Quick Start

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/claudito/master/install.sh | bash
```

### Use

```bash
# First, make sure Claude Code is authenticated
claude

# Then run claudito in any project directory
claudito

# Or pass arguments to Claude Code
claudito --help
claudito "write a hello world script"
```

## Installation

### One-liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/claudito/master/install.sh | bash
```

The installer will:
- Download claudito to `/usr/local/bin` or `~/.local/bin`
- Verify Docker is installed and running
- Check that all prerequisites are met

### Manual Install

```bash
# Download claudito script
curl -fsSL https://raw.githubusercontent.com/nikvdp/claudito/master/claudito > /usr/local/bin/claudito
chmod +x /usr/local/bin/claudito
```

## Usage

### Basic Usage

```bash
# Interactive Claude Code session
claudito

# Pass arguments to Claude Code
claudito "analyze this codebase"
claudito --resume

# Get help
claudito --help
```

### Advanced Usage

```bash
# Force rebuild the container image
claudito --rebuild

# Debug with interactive shell
claudito --shell

# Set environment variables
claudito --env API_KEY=sk-123 --env DEBUG=1

# Use .env file (automatic if present)
echo "DEBUG=1" > .env
claudito
```

### Environment Variables

Claudito automatically passes through common environment variables:

**Authentication & Configuration:**
- `ANTHROPIC_API_KEY` - API key fallback
- `ANTHROPIC_BASE_URL` - Custom API base URL
- `CLAUDE_CONFIG_DIR` - Claude configuration directory

**Development:**
- `NO_COLOR`, `TERM`, `COLORTERM` - Terminal settings
- `LANG`, `LC_ALL`, `TZ` - Locale settings
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL` - Git configuration

**Network:**
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` - Proxy settings

You can also:
- Add custom variables: `claudito --env CUSTOM_VAR=value`
- Use .env files: Create `.env` in your project directory
- Pass host variables: `claudito --env CUSTOM_VAR` (inherits from host)

## Requirements

- **Docker**: Installed and running
- **Claude Code**: Authenticated (`claude` command working)
- **Bash**: For the claudito script

### Authentication

Claudito automatically detects and uses your Claude Code authentication:

- **macOS**: Extracts credentials from Keychain
- **Linux**: Uses `~/.claude/.credentials.json`
- **Fallback**: `ANTHROPIC_API_KEY` environment variable

## Architecture

### Container Features

- **Base**: Node.js 20 with comprehensive toolchain
- **Tools**: jq, ripgrep, fzf, git, bat, PostgreSQL/SQLite clients, and more
- **Languages**: Python, Go, Rust, Java support
- **Security**: Minimal privileges, read-only credential mounts

### Build Process

1. **Credential Extraction**: Copies `~/.claude` directory and fresh credentials
2. **Image Build**: Creates container with your UID/GID for seamless file access
3. **Runtime**: Mounts current directory, preserves environment

### Security Model

- **Dropped Capabilities**: Runs with minimal Linux capabilities
- **UID/GID Mapping**: Container user matches host user
- **Read-only Mounts**: Credentials and config files mounted read-only
- **Network Restrictions**: Only necessary network capabilities
- **Isolated Environment**: Clean container state for each run

## Configuration

### Project-level Configuration

Create `.claudito.env` or `.env` in your project:

```bash
# Custom environment for this project
DEBUG=1
CUSTOM_API_URL=https://api.example.com
```

### Global Configuration

Claudito inherits all Claude Code configuration from `~/.claude/`:
- Slash commands
- Project settings  
- Authentication tokens
- User preferences

## Examples

### Development Workflow

```bash
# Start working on a project
cd my-project
claudito

# Run specific Claude Code commands
claudito "add tests for the auth module"
claudito --resume  # Continue previous conversation

# Debug container environment
claudito --shell
```

### CI/CD Usage

```bash
# In CI, use API key authentication
export ANTHROPIC_API_KEY=sk-your-key
claudito "review this pull request"
```

### With Custom Environment

```bash
# Set custom variables
claudito --env ENVIRONMENT=staging --env DEBUG=1 "deploy to staging"

# Or use .env file
echo "ENVIRONMENT=staging" > .env
echo "DEBUG=1" >> .env
claudito "check deployment status"
```

## Troubleshooting

### Common Issues

**"No Claude Code credentials found"**
- Run `claude` first to authenticate
- Make sure Claude Code is working outside the container

**"Docker daemon is not running"**
- Start Docker Desktop or Docker daemon
- Verify with `docker info`

**Permission errors**
- Claudito automatically handles UID/GID mapping
- Try `claudito --rebuild` if issues persist

**Authentication not working**
- Claudito copies credentials at build time
- Run `claudito --rebuild` after re-authenticating Claude Code

### Debug Mode

```bash
# Get an interactive shell in the container
claudito --shell

# Check what's mounted
claudito --shell
# Then in container: ls -la ~/.claude
```

## Contributing

Pull requests welcome! Please see [SECURITY.md](SECURITY.md) for security considerations.

## License

MIT License - see LICENSE file for details.