#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "🚀 Starting cross-platform build..."

# Linux ARM64
echo "📦 Building Linux ARM64..."
env GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bw_manager_lin_arm64

# Linux AMD64
echo "📦 Building Linux x64..."
env GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bw_manager_lin_x64

# Windows AMD64
echo "📦 Building Windows AMD64..."
env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bw_manager_win.exe

# macOS AMD64
echo "📦 Building macOS x64..."
env GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bw_manager_mac_x64

# macOS ARM64 (Apple Silicon)
echo "📦 Building macOS ARM64..."
env GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bw_manager_mac_arm64

echo "✅ All builds completed successfully!"
