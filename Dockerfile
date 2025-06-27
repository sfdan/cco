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
    # Database clients (minimal set)
    postgresql-client sqlite3 \
    # Network and system tools
    netcat-openbsd telnet dnsutils iputils-ping \
    # Container tools
    docker.io \
    # System administration
    sudo \
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

# Install uv (Python environment management tool)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# Create symlinks for fd (some systems call it fdfind)
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Install custom packages if specified
ARG CUSTOM_PACKAGES=""
RUN if [ -n "$CUSTOM_PACKAGES" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y $CUSTOM_PACKAGES && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Don't set a default user - let the entrypoint handle user creation and setup
# The entrypoint will create the appropriate user and set HOME correctly

# Don't set hardcoded environment variables - let entrypoint handle this
# Claude configuration will be mounted at runtime - no baking into image
# ccon provides secure, thin-wrapper containerization for Claude Code

# Set entrypoint for user management
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command: Run Claude Code
CMD ["claude", "--dangerously-skip-permissions"]