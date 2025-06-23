FROM node:20-bookworm

# Install system dependencies and modern shell tools
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    # Core development tools
    build-essential git curl wget vim nano \
    # Modern shell tools
    jq ripgrep fzf fd-find bat htop tmux \
    # Languages and runtimes
    python3 python3-pip python3-venv \
    golang-go rustc cargo \
    openjdk-17-jdk \
    # Database clients (minimal set)
    postgresql-client sqlite3 \
    # Network and system tools
    netcat-openbsd telnet dnsutils iputils-ping \
    # Container tools
    docker.io \
    # Misc utilities
    tree less file unzip zip \
    && rm -rf /var/lib/apt/lists/*

# Install packages not available in Debian repos
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create symlinks for fd (some systems call it fdfind)
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Install custom packages if specified
ARG CUSTOM_PACKAGES=""
RUN if [ -n "$CUSTOM_PACKAGES" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y $CUSTOM_PACKAGES && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Create user with default UID/GID (runtime --user will map to host)
RUN groupadd -g 1000 user || true
RUN useradd -u 1000 -g 1000 -ms /bin/bash user

# Switch to user
USER user
WORKDIR /home/user

# Copy system Claude configuration from host (extracted by claudito script)
COPY --chown=user:user .claude-system/ /home/user/.claude/

# Set environment variables
ENV HOME=/home/user
ENV CLAUDE_CONFIG_DIR=/home/user/.claude
ENV USER=user

# Set up shell environment with modern tools
RUN echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/user/.bashrc && \
    echo 'alias ll="ls -la"' >> /home/user/.bashrc && \
    echo 'alias cat="bat --paging=never"' >> /home/user/.bashrc && \
    echo 'alias find="fd"' >> /home/user/.bashrc

# Default command: Run Claude Code
CMD ["claude", "--dangerously-skip-permissions"]