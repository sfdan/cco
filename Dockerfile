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

# Note: exa and git-delta require newer Rust version than available in bookworm
# Users can use ls and git diff instead

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create symlinks for fd (some systems call it fdfind)
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Set up non-root user (following Anthropic's pattern)
RUN useradd -ms /bin/bash claude && \
    usermod -aG docker claude

# Switch to non-root user
USER claude
ENV HOME=/home/claude
WORKDIR /workspace

# Create claude config directory
RUN mkdir -p /home/claude/.claude

# Set up shell environment with modern tools
RUN echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/claude/.bashrc && \
    echo 'alias ll="ls -la"' >> /home/claude/.bashrc && \
    echo 'alias cat="bat --paging=never"' >> /home/claude/.bashrc && \
    echo 'alias find="fd"' >> /home/claude/.bashrc

# Default command: Start Claude Code with dangerous permissions skipped
# (safe because we're in a sandboxed container)
CMD ["claude", "--dangerously-skip-permissions"]