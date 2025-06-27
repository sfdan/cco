# ccon Development Guide for Claude

## What This Project Is

**ccon** (Claude Container, or Claude Condom if you're so inclined) is a Docker-based containerization wrapper for Claude Code. It provides "a thin protective layer for Claude Code" - running Claude Code inside a secure container while maintaining full functionality.

## Core Understanding You Need

### The Problem Being Solved
- Claude Code with `--dangerously-skip-permissions` is fast but risky (can access entire host)
- Permission prompts kill development flow  
- Users want autonomous Claude but with safety barriers
- Container isolation solves this: Claude gets full autonomy within a sandbox

### Architecture in 30 Seconds
```bash
Host System → Docker Container → Claude Code
     ↓              ↓              ↓
Project files → Mount read-write → Claude can edit
Credentials → Extract & mount → Claude can authenticate  
System → Isolated → Claude can't escape container
```

## Critical Development Principles

### 1. NEVER Break Authentication
- Credentials are NEVER baked into Docker images (security violation)
- Fresh extraction from Keychain (macOS) or files (Linux) every run
- System config mounted read-only, project config read-write
- If auth breaks, everything breaks - this is priority #1

### 2. NEVER Mix System and Project Config
```bash
# CORRECT separation:
host:~/.claude → container:/home/user/.claude (read-only)
host:$PROJECT/.claude → container:$PROJECT/.claude (read-write)

# WRONG - would corrupt user's global config:
host:~/.claude → container:$PROJECT/.claude ❌
```

### 3. User Expectations
- Should feel exactly like using `claude` directly
- All Claude Code options must pass through unchanged
- Container should be invisible to user workflow
- Failures should be obvious and recoverable

## Quick Diagnostic Commands

### When Something's Broken
```bash
# 1. Test basic functionality
./ccon "what is 2+2?"  # Should return "4" without auth prompts

# 2. Check authentication 
./ccon --shell "ls -la ~/.claude/.credentials.json"  # Should exist with proper ownership

# 3. Check user mapping
./ccon --shell "whoami && id"  # Should match host UID, not be "I have no name!"

# 4. Check working directory
./ccon --shell "pwd"  # Should be project directory, not /home/user

# 5. Nuclear option
./ccon --rebuild  # Rebuilds everything, pulls latest Claude Code
```

### Common Failure Patterns
- **"I have no name!" prompt**: UID mapping broken, check entrypoint script
- **Auth prompts inside container**: Credential mounting failed
- **Permission denied on files**: File ownership mismatch between host/container
- **Can't find project files**: Working directory not preserved
- **Build failures**: Usually Dockerfile or build context issues

## Key Architecture Details

### User Creation Strategy (docker-entrypoint.sh)
The container starts as root, creates a user matching host UID/GID, then switches to that user:
```bash
if [ "$HOST_UID" = "1000" ]; then
    # Use existing node user (Node.js base image conflict)
    USER_NAME="node"
elif ! id -u "$HOST_UID"; then
    # Create new user for non-standard UIDs (like macOS 501)
    useradd -u "$HOST_UID" -g "$HOST_GID" hostuser
    USER_NAME="hostuser"
fi
```

### Configuration Mounting Rules
```bash
# NEVER mix these up - this prevents data corruption:
host:~/.claude → .claude-system/ → container:/home/user/.claude (read-only)
host:$PROJECT/.claude → container:$PROJECT/.claude (read-write)
host:keychain → temp file → container:/home/user/.claude/.credentials.json
```

Why this matters:
- System config is user's global Claude settings (never touch)
- Project config is local overrides (safe to modify)
- Credentials are runtime-only (never persist)

## Development Workflow

### Pre-Commit Safety Ritual
**ALWAYS run this before committing major changes:**
```bash
./ccon "what is 2+2?"                    # Basic functionality
./ccon --shell whoami                    # User identity correct
./ccon --shell 'uv --version'            # Python tools work
./ccon "create a simple Python project"  # End-to-end Claude integration
./ccon --rebuild                         # Build system healthy
```
If ANY of these fail, DO NOT commit.

### Development Safety Principles
- **Safety first**: Never commit broken code, use atomic commits only
- **Git discipline**: Use `master` branch, stage specific files only
- **Test before commit**: Run the pre-commit safety ritual for any major changes

### When Working on Features

#### Experimental Features (Currently: OAuth refresh, credential management)
- All marked clearly as EXPERIMENTAL in help text and docs
- Default behavior never changes
- Explicit opt-in required (`--allow-oauth-refresh`)
- Safety mechanisms built-in (backups, race condition protection)

#### Architecture Changes
- Test with both UID 1000 (Linux) and UID 501 (macOS) scenarios
- Verify authentication works across platforms
- Check container can access project files
- Ensure working directory preservation

### Common Development Patterns

#### When Authentication Breaks
1. Check credential extraction from Keychain/files
2. Verify mount paths in container
3. Test with `./ccon --shell "ls -la ~/.claude/"`
4. Nuclear option: `./ccon --rebuild`

#### When Build Fails
1. Check build context (should be repo directory)
2. Verify Dockerfile exists and is accessible
3. Check for file permission issues
4. Try manual `docker build -t ccon:latest .`

#### When Container Behavior Changes
1. Test user mapping with `./ccon --shell "whoami && id"`
2. Check working directory with `./ccon --shell "pwd"`
3. Verify environment variables passed through correctly

### Branding Guidelines
- **Name**: `ccon - Claude Container (or Claude Condom if you're so inclined)`
- **Tagline**: `A thin protective layer for Claude Code`
- **Tone**: Professional-first with subtle humor

## When Claude Gets Confused

### "Where am I?" (New Session Context)
Read this file (CLAUDE.md) for technical context and architecture understanding

### "What's broken?"
Run the diagnostic commands above, check recent commits for changes

### "How do I test this?"
Use the pre-commit safety ritual, check in container with `--shell`

### "What's safe to change?"
- ccon script logic: generally safe
- Dockerfile: test carefully, affects all users
- Experimental features: already risky, document well
- Core auth/mounting: EXTREMELY DANGEROUS, test extensively