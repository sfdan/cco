#!/bin/sh
set -e

# Get host UID/GID from environment
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"

# If already running as the target user, just exec
if [ "$(id -u)" = "$HOST_UID" ]; then
	exec "$@"
fi

# Running as root, need to set up user
echo "▶ Setting up container user with UID:GID ${HOST_UID}:${HOST_GID}..."

# Create group if needed
if ! getent group "$HOST_GID" >/dev/null 2>&1; then
	groupadd -g "$HOST_GID" hostgroup
fi

# Handle user creation/modification
if [ "$HOST_UID" = "1000" ]; then
	# UID 1000 is the node user, just ensure it's in the right group
	usermod -a -G "$HOST_GID" node 2>/dev/null || true
	USER_NAME="node"
	USER_HOME="/home/node"
elif ! id -u "$HOST_UID" >/dev/null 2>&1; then
	# Create new user (suppress UID range warning for macOS UIDs)
	UID_MIN=100 UID_MAX=65000 useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/hostuser -s /bin/bash -m hostuser 2>/dev/null || useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/hostuser -s /bin/bash -m hostuser
	USER_NAME="hostuser"
	USER_HOME="/home/hostuser"
else
	# User already exists
	USER_NAME=$(id -nu "$HOST_UID")
	USER_HOME=$(getent passwd "$HOST_UID" | cut -d: -f6)
fi

# Fix ownership of mounted claude files
if [ -d "$USER_HOME/.claude" ]; then
	chown -R "$HOST_UID:$HOST_GID" "$USER_HOME/.claude" 2>/dev/null || true
fi
if [ -f "$USER_HOME/.claude.json" ]; then
	chown "$HOST_UID:$HOST_GID" "$USER_HOME/.claude.json" 2>/dev/null || true
fi

# Switch to the target user and run the command
# Build the command string properly, ensuring HOME is set correctly
cmd=""
for arg in "$@"; do
	# Escape single quotes in the argument
	escaped_arg=$(printf '%s\n' "$arg" | sed "s/'/'\\\\''/g")
	cmd="$cmd '$escaped_arg'"
done

# Set HOME environment variable and run command (preserve working directory)
exec su -s /bin/sh "$USER_NAME" -c "export HOME='$USER_HOME' && $cmd"
