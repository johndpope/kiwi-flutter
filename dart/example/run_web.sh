#!/bin/bash
# Helper script to clean and run Flutter web app with LAN access

set -e

PORT=${1:-3000}
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "🧹 Cleaning Flutter build..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔍 Running analyzer..."
flutter analyze lib/ || true

echo "🚀 Starting Flutter web on port $PORT with LAN access..."
# Kill any existing process on the port
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1

# Get git SHA for build info
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo ""
echo "📱 LAN Access URL: http://$LAN_IP:$PORT"
echo "💻 Local URL: http://localhost:$PORT"
echo ""

# --web-hostname 0.0.0.0 enables access from other devices on the network
flutter run -d chrome --web-port $PORT --web-hostname 0.0.0.0 --dart-define=GIT_SHA=$GIT_SHA
