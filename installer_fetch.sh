#!/bin/bash

# Makeself script to download and install a Solar2D plugin

# Variables
DOWNLOAD_URL="https://kwiksher.com/downloads/kwik5/beta/plugin.data.tgz"
PLUGIN_NAME="plugin"
PLUGIN_DIR="$HOME/Library/Application Support/Corona/Simulator/Plugins/$PLUGIN_NAME"
TEMP_FILE="/tmp/plugin.data.tgz"

# Create the plugin directory if it doesn't exist
mkdir -p "$PLUGIN_DIR"

# Download the plugin.data.tgz file
echo "Downloading plugin from $DOWNLOAD_URL..."
if curl -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
    echo "Download complete."
else
    echo "Failed to download the plugin. Please check your internet connection."
    exit 1
fi

# Remove old files before extraction
echo "Removing old plugin files..."
rm -f "$PLUGIN_DIR/kwikEditor.lua"
rm -rf "$PLUGIN_DIR/kwikEditor"
echo "Old files removed."

# Extract the plugin.data.tgz file
echo "Installing plugin to $PLUGIN_DIR..."
if tar -xzf "$TEMP_FILE" -C "$PLUGIN_DIR"; then
    echo "Plugin installed successfully!"
else
    echo "Failed to extract the plugin. The file may be corrupted."
    exit 1
fi

# Clean up
rm "$TEMP_FILE"

# Final message
echo "Installation complete. You can now use the plugin in the Solar2D Simulator."