.PHONY: help test-install clean

# Default target
help:
	@echo "Claudito Development Tasks"
	@echo ""
	@echo "  test-install  Test curl | bash installer (starts server, tests, cleans up)"
	@echo "  clean         Clean up test files"
	@echo "  help          Show this help message"

# Test the curl | bash installer with local server
test-install:
	@echo "🚀 Testing curl | bash installer..."
	@echo "Starting local server on port 5004..."
	@# Start server in background, save PID
	python3 -m http.server 5004 & echo $$! > /tmp/claudito-server.pid
	@sleep 2  # Give server time to start
	@echo "Testing installer..."
	curl -fsSL http://localhost:5004/install.sh > /tmp/claudito-test-install.sh
	CLAUDITO_INSTALL_URL=http://localhost:5004 bash /tmp/claudito-test-install.sh
	@echo ""
	@echo "🧹 Cleaning up..."
	@# Kill the server
	kill `cat /tmp/claudito-server.pid` 2>/dev/null || true
	rm -f /tmp/claudito-server.pid /tmp/claudito-test-install.sh
	@echo "✅ Installation test complete!"

# Clean up test files
clean:
	@echo "Cleaning up test files..."
	@# Kill any running server
	kill `cat /tmp/claudito-server.pid` 2>/dev/null || true
	rm -f /tmp/claudito-server.pid /tmp/claudito-test-install.sh
	@echo "✅ Cleanup complete"