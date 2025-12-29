#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}⚠️  Warning: copying ./stacks/local-nonprod.env to .env${NC}"
echo -e "${BLUE}📝 Requirements:${NC}"
echo "  1. /etc/hosts entry: 127.0.0.1 local.mailopoly.com"
echo "  2. SSL certificates in ./dev-certs/ (server.crt, server.key)"
echo "  3. Sudo access (needed for ports 80 and 443)"
echo ""
cp ./stacks/local-nonprod.env .env

# Function to check if MCP devtools server is running
check_mcp_devtools() {
    echo -e "\n${BLUE}🔍 Checking MCP devtools server...${NC}"
    
    # Check if the devtools-mcp process is running
    if pgrep -f "devtools-mcp" > /dev/null; then
        echo -e "${GREEN}✅ MCP devtools server process is running${NC}"
        
        # Try to connect to the server (assuming it runs on a specific port)
        # You may need to adjust this based on how your MCP server works
        if curl -s --connect-timeout 3 http://localhost:3001/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ MCP devtools server is responding${NC}"
        else
            echo -e "${YELLOW}⚠️  MCP devtools server process found but not responding on expected port${NC}"
        fi
    else
        echo -e "${RED}❌ MCP devtools server is not running${NC}"
        echo -e "${YELLOW}💡 To start it, run: npx tsx ~/devtools-mcp/src/index.ts${NC}"
        return 1
    fi
}

# Function to test Chrome DevTools Protocol connection
test_cdp_connection() {
    echo -e "\n${BLUE}🔍 Testing Chrome DevTools Protocol connection...${NC}"
    
    # Wait a moment for Chrome to start
    sleep 2
    
    # Test if Chrome DevTools is accessible
    if curl -s http://127.0.0.1:9222/json > /dev/null; then
        echo -e "${GREEN}✅ Chrome DevTools Protocol is accessible${NC}"
        
        # Get the first tab info
        TAB_INFO=$(curl -s http://127.0.0.1:9222/json | jq -r '.[0] | {id, title, url}' 2>/dev/null)
        if [ $? -eq 0 ] && [ "$TAB_INFO" != "null" ]; then
            echo -e "${GREEN}✅ Successfully retrieved tab information${NC}"
            echo "Tab info: $TAB_INFO"
        else
            echo -e "${YELLOW}⚠️  DevTools accessible but couldn't parse tab info (jq may not be installed)${NC}"
        fi
    else
        echo -e "${RED}❌ Chrome DevTools Protocol is not accessible${NC}"
        echo -e "${YELLOW}💡 Make sure Chrome is running with debugging enabled${NC}"
        return 1
    fi
}

# Function to test MCP functionality with Claude
test_mcp_with_claude() {
    echo -e "\n${BLUE}🔍 Testing MCP integration...${NC}"
    echo -e "${YELLOW}💡 To test MCP with Claude:${NC}"
    echo "1. Open Claude Desktop app"
    echo "2. Make sure devtools MCP server is configured"
    echo "3. Try running a cdp_command in Claude chat"
    echo "4. Example: Ask Claude to evaluate 'document.title' using CDP"
}

# Function to check if PM2 is installed
check_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo -e "${RED}❌ PM2 is not installed${NC}"
        echo -e "${YELLOW}💡 Install with: npm install -g pm2${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ PM2 is installed${NC}"
}

# Function to stop existing PM2 processes
stop_pm2_processes() {
    echo -e "\n${BLUE}🧹 Stopping existing PM2 processes...${NC}"

    # Check if mailopoly-local is running
    if pm2 describe mailopoly-local &>/dev/null; then
        echo -e "${YELLOW}⚠️  Stopping mailopoly-local PM2 process${NC}"
        pm2 stop mailopoly-local
        pm2 delete mailopoly-local
    fi

    # Kill any remaining processes on ports 80, 443, and 3030
    for PORT in 80 443 3030; do
        PORT_PID=$(lsof -ti:$PORT 2>/dev/null)
        if [ ! -z "$PORT_PID" ]; then
            echo -e "${YELLOW}⚠️  Killing process on port $PORT: $PORT_PID${NC}"
            sudo kill -9 $PORT_PID 2>/dev/null
            sleep 1
        fi
    done

    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
echo -e "${BLUE}🚀 Starting local development environment...${NC}"

# Check PM2 is installed
check_pm2

# Stop existing PM2 processes
stop_pm2_processes

# Check MCP devtools server
# check_mcp_devtools

# Check for SSL certificates
if [ ! -f "./dev-certs/server.crt" ] || [ ! -f "./dev-certs/server.key" ]; then
    echo -e "${RED}❌ SSL certificates not found in ./dev-certs/${NC}"
    echo -e "${YELLOW}💡 Generate them with:${NC}"
    echo "  mkdir -p dev-certs"
    echo "  openssl req -x509 -newkey rsa:4096 -keyout dev-certs/server.key -out dev-certs/server.crt -days 365 -nodes -subj '/CN=local.mailopoly.com'"
    exit 1
fi

# Start the dev server with PM2 (requires sudo for ports 80 and 443)
echo -e "\n${BLUE}🚀 Starting HTTPS dev server with PM2...${NC}"
echo -e "${YELLOW}⚠️  This requires sudo access for ports 80 and 443${NC}"
sudo PM2_HOME=$HOME/.pm2 pm2 start ecosystem.config.yml --only mailopoly-local

# Wait for server to start
echo -e "${YELLOW}⏳ Waiting for server to start...${NC}"
sleep 5

# Check if server is running
if sudo PM2_HOME=$HOME/.pm2 pm2 describe mailopoly-local &>/dev/null; then
    echo -e "${GREEN}✅ HTTPS dev server started successfully${NC}"
    echo -e "${GREEN}✅ HTTP (80) → HTTPS (443)${NC}"
    echo -e "${GREEN}✅ OAuth callbacks will work on standard ports${NC}"
    SERVER_STARTED=true
else
    echo -e "${RED}❌ Failed to start dev server${NC}"
    sudo PM2_HOME=$HOME/.pm2 pm2 logs mailopoly-local --lines 20
    exit 1
fi

# Start Chrome with remote debugging
echo -e "\n${BLUE}🚀 Starting Chrome with remote debugging...${NC}"
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --remote-debugging-address=127.0.0.1 \
  --user-data-dir=/tmp/chrome-debug \
  --no-first-run \
  --disable-default-apps \
  --start-maximized \
  https://local.mailopoly.com &

CHROME_PID=$!

# Test connections
test_cdp_connection
test_mcp_with_claude

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up processes...${NC}"

    # Stop PM2 process
    if [ "$SERVER_STARTED" = true ]; then
        echo -e "${YELLOW}⏹️  Stopping PM2 process mailopoly-local...${NC}"
        sudo PM2_HOME=$HOME/.pm2 pm2 stop mailopoly-local
        sudo PM2_HOME=$HOME/.pm2 pm2 delete mailopoly-local
    fi

    # Kill Chrome
    if [ ! -z "$CHROME_PID" ]; then
        kill $CHROME_PID 2>/dev/null
    fi

    echo -e "${GREEN}✅ Cleanup complete${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo -e "\n${GREEN}✅ Setup complete!${NC}"
echo -e "${BLUE}📝 Summary:${NC}"
echo "- HTTPS dev server running via PM2 (process: mailopoly-local)"
echo "- Server accessible at: https://local.mailopoly.com (port 443)"
echo "- HTTP redirect: http://local.mailopoly.com (port 80) → HTTPS"
echo "- Chrome running with remote debugging on port 9222"
echo ""
echo -e "${BLUE}📊 Useful PM2 commands (require sudo + PM2_HOME):${NC}"
echo "  sudo PM2_HOME=\$HOME/.pm2 pm2 logs mailopoly-local        # View logs"
echo "  sudo PM2_HOME=\$HOME/.pm2 pm2 restart mailopoly-local     # Restart server"
echo "  sudo PM2_HOME=\$HOME/.pm2 pm2 stop mailopoly-local        # Stop server"
echo "  sudo PM2_HOME=\$HOME/.pm2 pm2 monit                       # Monitor all processes"
echo "  sudo PM2_HOME=\$HOME/.pm2 pm2 list                        # List all processes"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all processes${NC}"

# Keep script running and tail logs
sudo PM2_HOME=$HOME/.pm2 pm2 logs mailopoly-local