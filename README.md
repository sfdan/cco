<div align="center">
    <img src="cco.svg" alt="cco logo" width="500">
</div>
<hr>


**cco** (Claude Container, or Claude Condom if you're so inclined) provides essential protection while Claude Code is up close and personal with your system.

## Why protection matters

Running Claude Code with `--dangerously-skip-permissions` feels great - fast, responsive, no interruptions. But going in unprotected has risks.

**cco lets you have it both ways: all the pleasure of autonomous Claude, with a barrier between Claude and your machine's sensitive areas.**

### The problem with exposure
- **Leaves Claude Unprotected**: Lightning fast but vulnerable to nasty prompt injections
- **Mood killer**: Constant permission prompts kill the flow

### Protected interaction
- **Smooth operation**: No more constant permission prompts
- **Barrier protection**: Keeps unwanted side effects contained
- **Peace of mind**: Enjoy the experience without worry
- **Easy cleanup**: Fresh environment every time

## Quick start

### Installation
```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/cco/master/install.sh | bash
```

### Usage
```bash
cco "write a hello world script"
cco "help me refactor this code"
```

## Design philosophy

**cco gets out of your way.** It's designed to feel natural - like using Claude directly, just safer.

- **Thin layer**: Barely noticeable protection
- **Natural feel**: Works exactly like `claude` but protected
- **No surprises**: Everything you expect, just contained
- **Seamless experience**: Your environment, your files, your workflow

You should barely notice `cco` is there, except for that reassuring feeling of safety.

## How it works

**cco runs Claude Code inside a Docker container.** This creates a sandboxed environment where Claude can operate with full autonomy while being isolated from your host system.

- **Docker sandbox**: Claude runs in an isolated container with its own filesystem
- **Host file access**: Your project files are mounted so Claude can read and edit them
- **Network isolation**: Claude's web access is contained within the container
- **Credential management**: Authentication is handled securely without exposing host credentials
- **Full toolchain**: Container includes development tools, languages, and utilities Claude needs

The result? Claude gets the `--dangerously-skip-permissions` experience it needs to be productive, while potential risks are contained within the sandbox.

## Installation

### One-liner install
```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/cco/master/install.sh | bash
```

### Manual setup
```bash
git clone https://github.com/nikvdp/cco.git
cd cco
chmod +x cco
sudo ln -s "$PWD/cco" /usr/local/bin/cco
```

## Usage

### Basic operation
```bash
# Interactive session
cco

# Direct commands  
cco "analyze this codebase"
cco --resume  # Claude Code option passed through

# Get help
cco --help
```

### Advanced options
```bash
# Rebuild the protective layer (also updates to latest Claude Code version)
cco --rebuild

# System information and status
cco --info

# Shell access for inspection
cco shell
cco shell 'ls -la'  # Run shell commands

# Custom environment
cco --env API_KEY=sk-123

# Additional apt packages
cco --packages terraform,kubectl

# Enable Docker access
cco --docker

# Update cco installation
cco self-update

# Clean up containers
cco cleanup
```

### Experimental features
⚠️ **These features are experimental and may have edge cases. Use with caution.**

```bash
# OAuth token refresh (EXPERIMENTAL)
# Allows Claude to refresh expired tokens and sync back to host system
cco --allow-oauth-refresh "help me code"

# Credential management (EXPERIMENTAL)  
# Backup and restore Claude Code credentials for safety
cco backup-creds                    # Backup current credentials
cco restore-creds                   # Restore from most recent backup
cco restore-creds backup-file.json  # Restore from specific backup
```

**OAuth refresh feature**: Enables bidirectional credential sync when Claude refreshes expired tokens. Uses race condition protection and creates automatic backups.

**Credential management**: Provides manual backup/restore of Claude Code credentials with cross-platform support (macOS Keychain + Linux files).

## Command Pass-through

cco acts as a wrapper - any options it doesn't recognize get passed directly to Claude Code:

```bash
# These Claude Code options work normally
cco --resume
cco --model claude-3-5-sonnet-20241022 "write tests"
cco --no-clipboard "analyze this file"

# Mix cco and Claude options
cco --env DEBUG=1 --resume  # cco + Claude options
```

## Configuration

### Environment setup
cco passes through everything you need:
- `ANTHROPIC_API_KEY` - Direct access
- Terminal settings (`TERM`, `NO_COLOR`)
- Git configuration
- Locale and timezone

### Project-level config
```bash
# Use .env files
echo "DEBUG=1" > .env
cco
```

## Requirements

- **Docker**: Must be running
- **Claude Code**: Must be authenticated
- **Bash**: For the wrapper

### Authentication
cco automatically finds your Claude credentials:
- **macOS**: Extracts from Keychain
- **Linux**: Uses `~/.claude/.credentials.json` or config directory
- **Environment**: `ANTHROPIC_API_KEY` passed through to container

## Architecture

### Container specs
- Node.js 20 with development tools
- Modern CLI utilities (jq, ripgrep, fzf)
- Multiple language support
- Database clients and network tools

### Safety features
- Isolated environment
- Secure credential mounting
- Proper permission mapping
- Fresh session every time

## Examples

### Development workflow
```bash
cd my-project
cco
cco "add tests to the auth module"
cco --resume
```

### CI/CD usage
```bash
export ANTHROPIC_API_KEY=sk-key
cco "review this pull request"
```

## Troubleshooting

**Authentication issues**
- Run `claude` first to authenticate
- Check Claude works outside cco

**Token expiration**
- If you get authentication errors, your OAuth token may have expired
- The containerized environment prevents automatic token refresh by default
- **Solution**: Run `claude` directly (outside cco) to re-authenticate, then retry with cco
- For automatic token refresh, try the experimental `--allow-oauth-refresh` flag (use with caution)

**Docker problems**
- Start Docker daemon
- Verify with `docker info`

**Permission errors**
- cco handles user mapping automatically
- Try `cco --rebuild` if needed

**Experimental features not working**
- OAuth refresh (`--allow-oauth-refresh`) is experimental and may have issues
- Fallback: authenticate directly with `claude` when tokens expire
- Use credential backup/restore commands for safety: `cco backup-creds` / `cco restore-creds`

### Debug access
```bash
cco shell  # Get inside for inspection
cco --info  # Check system status
```

## Security

cco provides a significant layer of protection, but like any barrier method, it's not 100% foolproof. It's certainly better than nothing, but:

- Keep your protection up to date
- Check it's working properly before each session
- Remember that no method is perfect

**For detailed security information, threat model, and limitations, see [SECURITY.md](SECURITY.md).**

**Practice safe computing.**

## Contributing

Pull requests welcome! Please maintain all safety mechanisms.

## License

MIT License
