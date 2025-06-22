# Security

Claudito is designed with security as a primary concern. This document outlines the security measures implemented and considerations for users.

## Security Model

### Container Isolation

**Principle**: Run Claude Code in a secure, isolated environment with minimal privileges.

**Implementation**:
- Container runs with dropped Linux capabilities
- UID/GID mapping ensures file permissions match host user
- Read-only mounts for sensitive configuration files
- Network access limited to necessary capabilities only

### Authentication Security

**Credential Handling**:
- Credentials extracted at build time, not runtime
- macOS: Secure extraction from Keychain using `security` command
- Linux: Copy existing `.credentials.json` file
- Credentials mounted read-only in container
- No credential modification or storage by claudito

**Authentication Flow**:
1. Host authentication verified before container build
2. Fresh credential extraction from secure storage
3. Build-time copying to container image
4. Runtime access via read-only mount

### Network Security

**Capabilities**:
- `NET_ADMIN` and `NET_RAW` capabilities added for Claude Code networking
- Minimal capability set - all others dropped
- No privileged container execution

**Traffic**:
- All network traffic originates from Claude Code
- Standard HTTPS to Anthropic APIs
- Proxy support via environment variables
- No additional network exposure

## Threat Model

### What Claudito Protects Against

✅ **Isolated Execution Environment**
- Code execution happens in container, not host
- File system isolation except for mounted project directory
- Process isolation from host system

✅ **Credential Isolation**
- Credentials not exposed to host filesystem during runtime
- Read-only access prevents credential modification
- Clean container state for each execution

✅ **Privilege Minimization**
- Non-root container execution
- Minimal Linux capabilities
- UID/GID mapping for seamless file access without privilege escalation

### What Claudito Does NOT Protect Against

❌ **Malicious Code Execution**
- Claude Code can still execute arbitrary commands in container
- Project directory is fully writable
- Git repositories and SSH keys are accessible

❌ **Network-based Attacks**
- Container has network access for Claude Code API calls
- Proxy settings inherited from host
- DNS resolution from container

❌ **Host System Compromise**
- If host system is compromised, container security is limited
- Shared kernel with host system
- Docker daemon runs as root

## Security Best Practices

### For Users

**Authentication**:
- Keep Claude Code credentials secure on host system
- Regularly rotate API keys if using `ANTHROPIC_API_KEY`
- Monitor Claude Code usage for unauthorized access

**Project Security**:
- Review code changes made by Claude Code before committing
- Use version control to track all modifications
- Be cautious with sensitive files in project directories

**Environment**:
- Keep Docker daemon updated
- Monitor container resource usage
- Use `.env` files for project-specific secrets, not global ones

### For Administrators

**Docker Security**:
- Configure Docker daemon with appropriate security policies
- Use Docker Content Trust in production environments
- Monitor container registry access

**Network Security**:
- Configure appropriate firewall rules
- Monitor network traffic from containers
- Use corporate proxies if required

**Audit Trail**:
- Log container execution events
- Monitor file system changes in mounted directories
- Track authentication events

## Security Features

### Container Hardening

```dockerfile
# Non-root user execution
USER user

# Minimal base image
FROM node:20-bookworm

# Dropped capabilities at runtime
--cap-drop=ALL --cap-add=NET_ADMIN --cap-add=NET_RAW
```

### File System Security

```bash
# Read-only credential mounts
-v "$HOME/.gitconfig":"/home/user/.gitconfig:ro"
-v "$HOME/.ssh":"/home/user/.ssh:ro"

# UID/GID mapping for proper permissions
--user "${host_uid}:${host_gid}"
```

### Environment Isolation

```bash
# Controlled environment variable passthrough
ANTHROPIC_API_KEY, ANTHROPIC_BASE_URL  # Authentication
NO_COLOR, TERM, LANG                   # Terminal/locale
HTTP_PROXY, HTTPS_PROXY               # Network
GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL     # Git config
```

## Incident Response

### Suspected Credential Compromise

1. **Immediate Actions**:
   - Revoke Claude Code session: `claude logout`
   - Regenerate API keys if using `ANTHROPIC_API_KEY`
   - Check recent Claude Code activity logs

2. **Investigation**:
   - Review container execution logs
   - Check file system modifications in project directories
   - Analyze network connections from containers

3. **Recovery**:
   - Re-authenticate Claude Code: `claude`
   - Rebuild claudito image: `claudito --rebuild`
   - Verify credential security

### Malicious Code Execution

1. **Containment**:
   - Stop running claudito containers: `docker stop $(docker ps -q --filter ancestor=claudito:latest)`
   - Review recent code changes in project directories
   - Check git history for unauthorized commits

2. **Analysis**:
   - Examine container logs: `docker logs claudito-$(basename "$PWD")`
   - Review file modifications in mounted directories
   - Check for persistence mechanisms

3. **Cleanup**:
   - Rebuild claudito image from scratch: `claudito --rebuild`
   - Review and revert unauthorized code changes
   - Update security policies if needed

## Reporting Security Issues

For security vulnerabilities in claudito:

1. **Do NOT** open a public GitHub issue
2. Email security concerns to the maintainer
3. Include detailed reproduction steps
4. Allow reasonable time for response before disclosure

For Claude Code security issues:
- Report to Anthropic through their official channels
- Follow Anthropic's responsible disclosure policy

## Security Checklist

Before using claudito in production environments:

- [ ] Docker daemon properly configured and updated
- [ ] Host system security hardening applied
- [ ] Network policies configured for container traffic
- [ ] Monitoring and logging enabled for container activity
- [ ] Incident response procedures documented
- [ ] Regular security reviews scheduled
- [ ] Backup and recovery procedures tested

## Security Assumptions

Claudito's security model assumes:

1. **Trusted Host Environment**: Host system is properly secured
2. **Docker Security**: Docker daemon is securely configured
3. **Network Security**: Network infrastructure provides appropriate protection
4. **User Responsibility**: Users review code changes before committing
5. **Anthropic Security**: Claude Code and Anthropic APIs are secure

If any of these assumptions don't hold in your environment, additional security measures may be required.