# Claudito

A minimal, secure way to run Claude Code in a Docker container with proper authentication handling.

## Why Claudito?

Claude Code's `--dangerously-skip-permissions` flag enables autonomous operation but **runs commands directly on your host system**. **Claudito gives you the speed of autonomous Claude with container protection.**

### The Problem
- Claude Code without `--dangerously-skip-permissions`: Constantly asks for permission, breaks flow
- Claude Code with `--dangerously-skip-permissions`: Fast and autonomous but **vulnerable to prompt injection attacks**

### The Solution  
Claudito runs Claude Code with `--dangerously-skip-permissions` **inside a secure container**, protecting you from:

- **Prompt Injection Attacks**: Malicious websites can't `rm -rf /` your system
- **Accidental Damage**: Mistakes are contained, not catastrophic  
- **Autonomous Speed**: No permission prompts, Claude works at full speed
- **Host Isolation**: Your real system stays safe

**If you don't need `--dangerously-skip-permissions`, just use `claude` directly.**

## Quick Start

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/claudito/master/install.sh | bash
```

### Use

```bash
# First, make sure Claude Code is authenticated
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
# Interactive Claude Code session (with --dangerously-skip-permissions enabled)
claudito

# Pass arguments to Claude Code (autonomous operation, container isolated)
claudito "analyze this codebase"
claudito --resume

# Get help
claudito --help
```

**Note**: Claudito runs Claude Code with `--dangerously-skip-permissions` by default. This allows Claude to work autonomously without permission prompts while keeping your host system protected by container isolation.

### Advanced Usage

```bash
# Force rebuild the container image
claudito --rebuild

# Debug with interactive shell
claudito --shell

# Set environment variables
claudito --env API_KEY=sk-123 --env DEBUG=1

# Install additional packages
claudito --packages terraform,ansible,helm

# Enable Docker access for Docker-in-Docker workflows
claudito --docker

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

### Custom Packages

Add your favorite CLI tools to the container:

```bash
# Install specific packages
claudito --packages terraform,kubectl,ansible

# Multiple packages for infrastructure work
claudito --packages "aws-cli,terraform,helm,jq"
```

**Note**: Custom packages trigger an automatic image rebuild and are installed via `apt-get`.

### Docker Access

Enable Docker-in-Docker for containerized development workflows:

```bash
# Enable Docker access inside claudito
claudito --docker

# Now Claude can run docker commands, build images, etc.
claudito --docker "help me containerize this app"
```

**Note**: This bind mounts your host Docker socket, allowing Claude to manage containers on your host system. Use with appropriate caution.

### Advanced: Custom Dockerfile

For complex customizations, you can modify the Dockerfile directly:

```dockerfile
# Add after the existing RUN commands
RUN curl -fsSL https://get.docker.com | sh  # Install Docker
RUN npm install -g some-node-tool           # Node.js tools
RUN pip3 install some-python-package        # Python packages
```

Then rebuild: `claudito --rebuild`

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
# Start working on a project (full Claude Code power, safely contained)
cd my-project
claudito

# Run specific Claude Code commands (autonomous operation, no permission prompts)
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