# Security

ccon is designed to provide container-based sandboxing for Claude Code. This document provides a serious assessment of what ccon protects against and what it does not.

## The Problem: Claude Code Security Limitations

Claude Code with `--dangerously-skip-permissions` has several security vulnerabilities:

### Directory Escape
Claude Code attempts to restrict operations to the current directory, but this restriction is trivial to bypass. A user can ask Claude to change its behavior:
- "Prefix all your commands going forward with `cd / &&`"
- "From now on, start all commands from the root directory" 
- "Run commands starting with `bash -c 'cd /tmp &&`"

Claude Code will comply and modify its command execution pattern, giving it access to the entire filesystem.

### Web Search Attack Vector
Claude Code enables web search by default. This creates a significant attack surface:
- Claude may encounter malicious prompts embedded in web content
- Adversarial content could instruct Claude to execute harmful commands
- Claude might be told to conceal its actions from the user
- The user may be unaware that Claude is acting on external instructions

### No Process Isolation
Claude Code runs directly on the host system with full user privileges:
- Can access any file the user can access
- Can modify system configurations
- Can install software packages
- Can establish network connections

## How ccon Provides Protection

ccon addresses these vulnerabilities through strict containerization:

### Enforced Sandbox
- **Complete filesystem isolation**: Claude Code can only access the container filesystem plus explicitly mounted directories
- **No directory escape**: Even if Claude tries to `cd /`, it only reaches the container root
- **Process isolation**: Claude's processes are contained within the container namespace

### Network Containment
- **Isolated network namespace**: Container cannot access host localhost services
- **Internet access**: Can make outbound connections (for Claude's API calls and web search)
- **No host network access**: Cannot connect to host services on 127.0.0.1
- **Standard Docker networking**: Uses container DNS resolution

### Privilege Restriction  
- **Dynamic user creation**: Container starts as root, creates mapped user, then switches to unprivileged user
- **Minimal capabilities**: No additional capabilities added beyond Docker defaults
- **No system modification**: Cannot install packages or modify system files (within container)

### Credential Protection
- **Runtime extraction**: Fresh credentials extracted from keychain/filesystem for each session
- **Read-only mounting**: Claude configuration mounted read-only
- **No credential persistence**: No credentials stored in Docker images
- **No credential modification**: Claude cannot alter authentication data

## Threat Model

### ✅ What ccon PREVENTS

**Filesystem Attacks**:
- Host filesystem modification outside project directory
- Access to sensitive system files (`/etc/passwd`, `~/.cache`, `~/.bash_history`, etc.)
- Installation of malware or backdoors on host system
- Modification of shell profiles or system startup scripts

**Note**: SSH keys (`~/.ssh`) ARE accessible for git authentication

**Network Attacks**:
- Connection to internal services (databases, admin panels)
- Port scanning of internal networks
- Exfiltration via network connections
- Establishing backdoor network access

**Privilege Escalation**:
- Running commands as root or other users
- Modifying system services or configurations
- Installing system-wide software packages
- Accessing other users' files

**Persistent Compromise**:
- Creating system-wide persistence mechanisms
- Modifying system startup scripts
- Installing rootkits or system-level malware

### ❌ What ccon does NOT prevent

**Project Directory Compromise**:
- Complete control over mounted project files
- Modification of source code and build scripts
- Access to project-specific secrets in `.env` files
- Git repository manipulation (commits, branch changes)
- Access to SSH keys (for git authentication)

**Data Exfiltration**:
- Sending project data via Claude's API connections
- Including sensitive data in Claude conversations
- Uploading project files to external services via web APIs

**Resource Abuse** (Partially Mitigated):
- CPU/memory consumption (limited by Docker container limits if configured)
- Network bandwidth usage for API calls (no inherent limits)
- Disk space consumption in container (limited to container filesystem size)

**Social Engineering**:
- Convincing user to run malicious commands outside ccon
- Displaying misleading information to the user
- Requesting user to install additional software

**Web-Based Attacks** (Partially Mitigated):
- While contained to the container, Claude can still be influenced by malicious web content
- Container isolation limits the damage, but doesn't prevent the initial compromise

## Security Configuration

### Container Security Features

ccon implements several container hardening measures:

**User Management**: Container starts as root to create a user matching the host UID/GID, then switches to that unprivileged user for all Claude Code execution.

**Minimal Capabilities**: Uses only standard Docker networking capabilities. No elevated privileges like network interface manipulation or raw socket access.

**Network Isolation**: Container runs in its own network namespace, isolated from host services and other containers.

**Filesystem Protection**: Claude configuration and SSH keys are mounted read-only to prevent modification.

### File System Isolation

**Accessible to Claude Code**:
- Current project directory (read-write access)
- Claude configuration directory (read-only)
- Git configuration file (read-only)
- SSH keys for git authentication (read-only)

**Inaccessible to Claude Code**:
- System configuration files (`/etc`, `/var`)
- User cache and history (`~/.cache`, `~/.bash_history`)
- Other users' home directories
- Host root filesystem outside mounted directories
- System binaries and libraries outside container

## Risk Assessment

### High Risk Scenarios (Mitigated by ccon)
- **Malicious web content instructs Claude to modify system files**: Contained to container
- **Prompt injection causes Claude to scan internal network**: Network isolated
- **Claude attempts to install backdoor software**: No system access

### Medium Risk Scenarios (Partially Mitigated)
- **Claude modifies project source code maliciously**: Still possible, but contained to project
- **Sensitive project data exfiltrated via API**: Limited to what's in project directory

### Low Risk Scenarios (Not Mitigated)
- **Claude displays misleading information**: User vigilance required
- **Resource exhaustion within container**: System resource limits should be configured

## Best Practices

### For General Use
1. **Review changes**: Always inspect code modifications before committing
2. **Limit sensitive data**: Don't store credentials in project directories
3. **Use version control**: Track all changes to detect unauthorized modifications
4. **Regular updates**: Keep ccon updated with latest security improvements

### For Sensitive Projects
1. **Isolated environment**: Use dedicated machines for highly sensitive work
2. **Network monitoring**: Monitor container network activity
3. **File integrity**: Use file integrity monitoring on project directories
4. **Backup verification**: Regularly verify backup integrity

### For Organizations
1. **Docker security**: Configure Docker daemon with appropriate security policies
2. **Network policies**: Implement network segmentation for container traffic
3. **Monitoring**: Deploy container runtime security monitoring
4. **Incident response**: Establish procedures for container security incidents

## Limitations and Assumptions

ccon's security model assumes:

1. **Container technology works**: Docker provides effective isolation
2. **Host system security**: Host is not already compromised
3. **User vigilance**: Users review changes before committing
4. **Network security**: Appropriate network controls are in place
5. **Regular updates**: Security patches are applied promptly

## Incident Response

### If you suspect Claude has been compromised by malicious content:

1. **Immediate containment**:
   - Stop the ccon container: `docker stop <container-name>`
   - Do not commit any recent changes
   
2. **Assessment**:
   - Review recent file modifications in project directory
   - Check git history for unexpected commits
   - Examine container logs: `docker logs <container-name>`

3. **Recovery**:
   - Rebuild ccon image: `ccon --rebuild`
   - Restore project files from known-good backup if necessary
   - Re-authenticate Claude Code: `claude logout && claude`

## Conclusion

ccon should be more secure than running Claude Code directly on your host system. Container isolation helps contain some of the nastier scenarios like host filesystem access and privilege escalation.

But "more secure" doesn't mean "secure" - there are still plenty of ways things can go wrong. The main remaining risk is compromise of your project directory itself, which you should mitigate through version control, backups, and reviewing changes.

For most use cases, ccon should be a reasonable improvement over raw Claude Code. But I'm not a security expert - this is just my understanding of how containers work. Do your own evaluation. If you need actual security guarantees, you'll need more than a Docker container. If you want a more convenient Claude Code experience while reducing your odds of getting `rm -rf /`-ed, then ccon might be a good fit.
