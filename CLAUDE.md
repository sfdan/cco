# cco Development Guide for Claude

## What This Project Is

**cco** (Claude Container, or Claude Condom if you're so inclined) is a Docker-based containerization wrapper for Claude Code. It provides "a thin protective layer for Claude Code" - running Claude Code inside a secure container while maintaining full functionality.

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
./cco "what is 2+2?"  # Should return "4" without auth prompts

# 2. Check authentication 
./cco --shell "ls -la ~/.claude/.credentials.json"  # Should exist with proper ownership

# 3. Check user mapping
./cco --shell "whoami && id"  # Should match host UID, not be "I have no name!"

# 4. Check working directory
./cco --shell "pwd"  # Should be project directory, not /home/user

# 5. Nuclear option
./cco --rebuild  # Rebuilds everything, pulls latest Claude Code
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
if ! id -u "$HOST_UID"; then
    # Create new user with exact host UID/GID mapping
    useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/hostuser -s /bin/bash -m hostuser
    USER_NAME="hostuser"
else
    # User already exists
    USER_NAME=$(id -nu "$HOST_UID")
fi
```

**Key changes from earlier versions:**
- Removed Node.js base image dependency (now uses clean Debian base)
- Always creates `hostuser` for consistent behavior across platforms
- No special case for UID 1000 (eliminates permission conflicts)

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

## OAuth Credential Refresh Architecture

### The Platform Challenge

**macOS vs Linux credential storage creates fundamental architectural differences:**

#### macOS Host Systems
- **Credentials**: Stored in macOS Keychain, accessed via `security` command
- **No credential file**: No `~/.claude/.credentials.json` exists on host
- **Container problem**: Linux container cannot directly access macOS Keychain
- **Bridge requirement**: Must create/maintain a credential file for containers

#### Linux Host Systems  
- **Credentials**: Stored in `~/.claude/.credentials.json` file
- **Direct mounting**: Can bind mount actual credential file to containers
- **Simple flow**: Container updates propagate directly to host

### The OAuth Refresh Problem

**Current Issue (as of 2025-06-29):**
1. Container mounts credentials read-only → OAuth refresh fails in container
2. Even with `--allow-oauth-refresh`, macOS Keychain updates fail from container context
3. Token expiration during session requires manual restart workflow

**Root Cause:**
- macOS: Container process cannot write to host Keychain due to security restrictions
- Linux: Should work but needs read-write credential mounting
- Race conditions: Multiple cco sessions can invalidate each other's refresh tokens

### Proposed Solution Architecture

#### Core Principles
1. **Centralized credential state**: All sessions share single credential source
2. **Platform-specific bridging**: Handle macOS/Linux differences transparently  
3. **Real-time sync**: Changes propagate between container and host
4. **Atomic updates**: File locking prevents race conditions

#### Implementation Plan

**macOS Host Flow:**
```
Keychain → ~/.local/share/cco/credentials.json → Container (r/w mount)
   ↑              ↓
   └─── Sync ─────┘ (on container credential updates)
```

**Linux Host Flow:**
```
~/.claude/.credentials.json → Container (r/w mount, direct)
```

**Key Components:**
1. **Bridge file**: `~/.local/share/cco/credentials.json` for macOS hosts
2. **Credential sync**: Host process monitors container updates
3. **Polling-based**: Simple file watching (2-second intervals)
4. **File locking**: Prevent concurrent refresh conflicts

### Implementation Details

#### Startup Credential Setup
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Extract Keychain → bridge file
    local bridge_creds="${XDG_DATA_HOME:-$HOME/.local/share}/cco/credentials.json"
    mkdir -p "$(dirname "$bridge_creds")"
    security find-generic-password -s "Claude Code-credentials" -a "$USER" -w > "$bridge_creds"
    docker_args+=(-v "$bridge_creds":"$container_home/.claude/.credentials.json")
else
    # Linux: Direct mount
    docker_args+=(-v "$host_system_claude_dir/.credentials.json":"$container_home/.claude/.credentials.json")
fi
```

#### Background Sync Process (macOS only)
```bash
start_credential_sync() {
    local bridge_file="$1"
    while container_running; do
        if file_changed "$bridge_file"; then
            # Container updated credentials, sync to Keychain
            flock "$bridge_file.lock" security add-generic-password -U [...]
        fi
        sleep 2
    done
}
```

#### Communication Directory
- **Location**: `$PWD/.cco/comm/` (per-project to avoid session conflicts)
- **Purpose**: Signal credential updates from container to host
- **Files**: Flag files like `credential-updated` for event notification

### Current Limitations & Future Work

#### What We're Implementing First
1. **cco-initiated OAuth refresh**: Container → host credential updates
2. **Centralized cco state**: All cco sessions share credential bridge
3. **Basic file locking**: Prevent refresh token race conditions

#### What We're NOT Implementing Initially
1. **External Claude detection**: No polling of Keychain for external changes
2. **Bidirectional sync**: External macOS Claude updates won't auto-propagate to cco
3. **Advanced conflict resolution**: Basic file locking only

#### Known Edge Cases
- **External Claude updates**: User must manually restart cco sessions
- **Keychain authorization**: May require user interaction on first run
- **Multiple host users**: Bridge files are per-user in XDG data directory, no shared state

### Security Considerations

#### Keychain Access Model
- **Terminal context**: Better Keychain access than container processes
- **User authorization**: May prompt for permission on first credential access
- **Credential exposure**: Bridge files contain plaintext credentials (600 permissions)

#### File Security
- **Bridge file**: `~/.local/share/cco/credentials.json` with 600 permissions
- **Lock files**: Prevent concurrent access during updates
- **Cleanup**: Remove bridge files on exit (or persist for performance?)

### Debugging OAuth Issues

#### Common Failure Scenarios
1. **Container read-only mount**: Check mount permissions in docker args
2. **Keychain write failure**: Terminal context vs container context permissions
3. **Race conditions**: Multiple sessions refreshing simultaneously
4. **File locking**: Deadlocks or permission issues with lock files

#### Diagnostic Commands
```bash
# Check bridge file exists and has content
ls -la ~/.local/share/cco/credentials.json

# Verify Keychain access
security find-generic-password -s "Claude Code-credentials" -a "$USER" -w

# Test container credential access
./cco shell 'cat ~/.claude/.credentials.json | head -1'
```

### Architecture Evolution

This OAuth refresh architecture represents a significant evolution in cco's credential handling:

**Phase 1 (Original)**: Simple credential extraction and read-only mounting
**Phase 2 (Current)**: Experimental OAuth refresh with sync-back attempts  
**Phase 3 (Proposed)**: Centralized credential state with platform-specific bridges
**Phase 4 (Future)**: Full bidirectional sync with external Claude detection

The architecture must balance security, reliability, and user experience while handling the fundamental differences between macOS and Linux credential storage models.

## Development Workflow

### Pre-Commit Safety Ritual
**ALWAYS run this before committing major changes:**
```bash
./cco "what is 2+2?"                    # Basic functionality
./cco --shell whoami                    # User identity correct
./cco --shell 'uv --version'            # Python tools work
./cco "create a simple Python project"  # End-to-end Claude integration
./cco --rebuild                         # Build system healthy
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
3. Test with `./cco --shell "ls -la ~/.claude/"`
4. Nuclear option: `./cco --rebuild`

#### When Build Fails
1. Check build context (should be repo directory)
2. Verify Dockerfile exists and is accessible
3. Check for file permission issues
4. Try manual `docker build -t cco:latest .`

#### When Container Behavior Changes
1. Test user mapping with `./cco --shell "whoami && id"`
2. Check working directory with `./cco --shell "pwd"`
3. Verify environment variables passed through correctly

### Branding Guidelines
- **Name**: `cco - Claude Container (or Claude Condom if you're so inclined)`
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
- cco script logic: generally safe
- Dockerfile: test carefully, affects all users
- Experimental features: already risky, document well
- Core auth/mounting: EXTREMELY DANGEROUS, test extensively