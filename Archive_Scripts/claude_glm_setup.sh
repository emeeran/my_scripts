#!/bin/bash

# GLM 4.6 Setup Script for Claude Code CLI
# This script sets up everything needed to use Z.AI's GLM 4.6 with Claude Code

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GLM 4.6 Setup for Claude Code ===${NC}\n"

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for port to be ready
wait_for_port() {
    local port=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:$port/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

# Check if Z.AI API key is provided
if [ -z "$ZAI_API_KEY" ]; then
    echo -e "${YELLOW}Enter your Z.AI API key:${NC}"
    read -r ZAI_API_KEY
    
    if [ -z "$ZAI_API_KEY" ]; then
        echo -e "${RED}Error: API key is required${NC}"
        exit 1
    fi
fi

# Validate API key format (basic check)
if [ ${#ZAI_API_KEY} -lt 10 ]; then
    echo -e "${RED}Error: API key seems too short. Please check your key.${NC}"
    exit 1
fi

# Step 1: Check Python installation
echo -e "${YELLOW}[1/6] Checking Python installation...${NC}"
if ! command_exists python3; then
    echo -e "${RED}Error: Python 3 is required but not installed${NC}"
    echo "Install it with: sudo apt install python3 python3-pip"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo -e "${GREEN}✓ Python ${PYTHON_VERSION} found${NC}"

# Step 2: Check and install LiteLLM
echo -e "\n${YELLOW}[2/6] Checking LiteLLM installation...${NC}"
if ! command_exists litellm; then
    echo "Installing LiteLLM (this may take a minute)..."
    pip3 install --user litellm[proxy] || {
        echo -e "${RED}Error: Failed to install LiteLLM${NC}"
        echo "Try: pip3 install --user --upgrade pip"
        echo "Then re-run this script"
        exit 1
    }
    
    # Add user bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        echo -e "${BLUE}Added ~/.local/bin to PATH${NC}"
    fi
    
    echo -e "${GREEN}✓ LiteLLM installed${NC}"
else
    echo -e "${GREEN}✓ LiteLLM already installed${NC}"
fi

# Verify litellm is accessible
if ! command_exists litellm; then
    echo -e "${RED}Error: LiteLLM installed but not in PATH${NC}"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

# Step 3: Check for port conflicts
echo -e "\n${YELLOW}[3/6] Checking port availability...${NC}"
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}Port 8000 is in use. Attempting to free it...${NC}"
    pkill -f "litellm.*8000" 2>/dev/null || true
    sleep 2
    
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}Error: Port 8000 is still in use${NC}"
        echo "Please free the port manually or use a different port"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Port 8000 is available${NC}"

# Step 4: Create config directory
echo -e "\n${YELLOW}[4/6] Creating configuration...${NC}"
CONFIG_DIR="$HOME/.glm-claude"
mkdir -p "$CONFIG_DIR"

# Create LiteLLM config file
CONFIG_FILE="$CONFIG_DIR/config.yaml"
cat > "$CONFIG_FILE" << EOF
model_list:
  - model_name: claude-sonnet-4.5-20250929
    litellm_params:
      model: glm-4.6
      api_key: ${ZAI_API_KEY}
      api_base: https://open.bigmodel.cn/api/paas/v4
      timeout: 600
      stream_timeout: 600

  - model_name: claude-sonnet-4-20250514
    litellm_params:
      model: glm-4.6
      api_key: ${ZAI_API_KEY}
      api_base: https://open.bigmodel.cn/api/paas/v4
      timeout: 600
      stream_timeout: 600

general_settings:
  master_key: glm-proxy-key-$(date +%s)
  drop_params: true
  max_parallel_requests: 100
EOF

MASTER_KEY=$(grep "master_key:" "$CONFIG_FILE" | awk '{print $2}')
echo -e "${GREEN}✓ Configuration created${NC}"

# Step 5: Test API connection before starting proxy
echo -e "\n${YELLOW}[5/6] Testing Z.AI API connection...${NC}"
API_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    https://open.bigmodel.cn/api/paas/v4/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ZAI_API_KEY}" \
    -d '{
        "model": "glm-4.6",
        "messages": [{"role": "user", "content": "test"}],
        "max_tokens": 10
    }' 2>&1)

if [ "$API_TEST" != "200" ]; then
    echo -e "${RED}Error: Cannot connect to Z.AI API (HTTP $API_TEST)${NC}"
    echo "Please check:"
    echo "  1. Your API key is correct"
    echo "  2. Your internet connection"
    echo "  3. Z.AI service is accessible"
    exit 1
fi
echo -e "${GREEN}✓ Z.AI API connection successful${NC}"

# Step 6: Start LiteLLM proxy
echo -e "\n${YELLOW}[6/6] Starting GLM 4.6 proxy...${NC}"

# Stop any existing proxy
pkill -f "litellm.*8000" 2>/dev/null || true
sleep 1

# Start proxy with detailed logging
nohup litellm --config "$CONFIG_FILE" --port 8000 --detailed_debug > "$CONFIG_DIR/proxy.log" 2>&1 &
PROXY_PID=$!
echo "$PROXY_PID" > "$CONFIG_DIR/proxy.pid"

echo "Starting proxy (PID: $PROXY_PID)..."

# Wait for proxy to be ready
if wait_for_port 8000; then
    echo -e "${GREEN}✓ Proxy started successfully${NC}"
else
    echo -e "${RED}Error: Proxy failed to start within 30 seconds${NC}"
    echo -e "\n${YELLOW}Last 20 lines of log:${NC}"
    tail -n 20 "$CONFIG_DIR/proxy.log"
    echo -e "\n${YELLOW}Full log at: $CONFIG_DIR/proxy.log${NC}"
    exit 1
fi

# Verify proxy health
PROXY_HEALTH=$(curl -s http://localhost:8000/health 2>&1)
if [[ "$PROXY_HEALTH" == *"healthy"* ]] || [[ "$PROXY_HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Proxy health check passed${NC}"
else
    echo -e "${YELLOW}Warning: Unexpected health check response${NC}"
fi

# Step 7: Configure environment
echo -e "\n${YELLOW}Configuring Claude Code environment...${NC}"

# Clear conflicting variables
unset ANTHROPIC_AUTH_TOKEN

# Set new variables
export ANTHROPIC_API_KEY="$MASTER_KEY"
export ANTHROPIC_BASE_URL="http://localhost:8000"

# Create a helper script for future sessions
HELPER_SCRIPT="$CONFIG_DIR/activate.sh"
cat > "$HELPER_SCRIPT" << 'EOFHELPER'
#!/bin/bash
# Source this file to activate GLM 4.6 for Claude Code

CONFIG_DIR="$HOME/.glm-claude"

# Check if proxy is running
if [ -f "$CONFIG_DIR/proxy.pid" ]; then
    PID=$(cat "$CONFIG_DIR/proxy.pid")
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "Proxy not running. Starting..."
        nohup litellm --config "$CONFIG_DIR/config.yaml" --port 8000 --detailed_debug > "$CONFIG_DIR/proxy.log" 2>&1 &
        echo $! > "$CONFIG_DIR/proxy.pid"
        sleep 5
        echo "✓ Proxy started"
    else
        echo "✓ Proxy already running (PID: $PID)"
    fi
else
    echo "Starting proxy..."
    nohup litellm --config "$CONFIG_DIR/config.yaml" --port 8000 --detailed_debug > "$CONFIG_DIR/proxy.log" 2>&1 &
    echo $! > "$CONFIG_DIR/proxy.pid"
    sleep 5
    echo "✓ Proxy started"
fi

MASTER_KEY=$(grep "master_key:" "$CONFIG_DIR/config.yaml" | awk '{print $2}')
unset ANTHROPIC_AUTH_TOKEN
export ANTHROPIC_API_KEY="$MASTER_KEY"
export ANTHROPIC_BASE_URL="http://localhost:8000"

echo "✓ GLM 4.6 environment activated for Claude Code"
echo ""
echo "Current configuration:"
echo "  API Base: $ANTHROPIC_BASE_URL"
echo "  Model: GLM 4.6"
EOFHELPER

chmod +x "$HELPER_SCRIPT"

# Create stop script
STOP_SCRIPT="$CONFIG_DIR/stop.sh"
cat > "$STOP_SCRIPT" << 'EOFSTOP'
#!/bin/bash
# Stop the GLM 4.6 proxy

CONFIG_DIR="$HOME/.glm-claude"

if [ -f "$CONFIG_DIR/proxy.pid" ]; then
    PID=$(cat "$CONFIG_DIR/proxy.pid")
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID"
        rm "$CONFIG_DIR/proxy.pid"
        echo "✓ Proxy stopped"
    else
        echo "Proxy is not running"
        rm -f "$CONFIG_DIR/proxy.pid"
    fi
else
    # Try to kill by process name anyway
    pkill -f "litellm.*8000" && echo "✓ Proxy stopped" || echo "No proxy found"
fi
EOFSTOP

chmod +x "$STOP_SCRIPT"

# Create logs viewer script
LOGS_SCRIPT="$CONFIG_DIR/logs.sh"
cat > "$LOGS_SCRIPT" << 'EOFLOGS'
#!/bin/bash
# View GLM proxy logs

CONFIG_DIR="$HOME/.glm-claude"
tail -f "$CONFIG_DIR/proxy.log"
EOFLOGS

chmod +x "$LOGS_SCRIPT"

echo -e "${GREEN}✓ Environment configured${NC}"

# Summary
echo -e "\n${GREEN}==========================================${NC}"
echo -e "${GREEN}   Setup Complete! 🎉${NC}"
echo -e "${GREEN}==========================================${NC}\n"

echo -e "Claude Code is now configured to use ${BLUE}GLM 4.6${NC}\n"

echo -e "${YELLOW}Usage:${NC}"
echo -e "  claude-code \"Write a hello world function in Python\"\n"

echo -e "${YELLOW}For new terminal sessions:${NC}"
echo -e "  source ~/.glm-claude/activate.sh\n"

echo -e "${YELLOW}Management commands:${NC}"
echo -e "  Stop proxy:  ~/.glm-claude/stop.sh"
echo -e "  View logs:   ~/.glm-claude/logs.sh\n"

echo -e "${YELLOW}Troubleshooting:${NC}"
echo -e "  Logs:        cat ~/.glm-claude/proxy.log"
echo -e "  Status:      curl http://localhost:8000/health\n"

echo -e "${GREEN}Test it now:${NC}"
echo -e "  claude-code \"Write a hello world function in Python\"\n"
