#!/bin/bash

path=$(dirname "$0")

LIBRARY_NAME="kwik"
LIBRARY_TYPE="plugin"

# Verify arguments
usage() {
	echo "$0 [daily_build_number [dst_dir]]"
	echo ""
	echo "  daily_build_number: The daily build number, e.g. 2015.2560"
	echo "  dst_dir: If not provided, will be '$path/build'"
	exit -1
}

# Checks exit value for error
checkError() {
	if [ $? -ne 0 ]; then
		echo "Exiting due to errors (above)"
		exit -1
	fi
}

# Canonicalize relative paths to absolute paths
pushd "$path" > /dev/null
	dir=$(pwd)
	path=$dir
popd > /dev/null

# Default target version.
BUILD_TARGET="$1"
if [ -z "$BUILD_TARGET" ]; then
	BUILD_TARGET="2017.3032"
fi

# Default build directory.
BUILD_DIR="$2"
if [ ! -e "$BUILD_DIR" ]; then
	BUILD_DIR="$path/build"
fi

# Set lua compiler.
LUAC="$path/bin/luac"
BUILD_TARGET_VM="lua_51"
if [ ! -z "$3" ]; then
	LUAC="$path/bin/luac-$3"
	BUILD_TARGET_VM="$3"

	# Verify that this VM is supported.
	if [ ! -f "$LUAC" ]; then
		echo "Error: Lua VM '$3' is not supported."
		exit -1
	fi
fi

# Clean build directory.
if [ -e "$BUILD_DIR" ]; then
	rm -rf "$BUILD_DIR"
fi

# Get our Lua directory.
BUILD_DIR_LUA="$BUILD_DIR/plugins/$BUILD_TARGET/lua/$BUILD_TARGET_VM"
mkdir -p "$BUILD_DIR_LUA"

# Copy
echo "[copy]"
cp -vrf "$path/lua/$LIBRARY_TYPE" "$BUILD_DIR_LUA"
checkError

cp -vrf "$path"/metadata.json "$BUILD_DIR"
checkError

# Remove .git directories after copying
echo ""
echo "[removing .git directories]"
find "$BUILD_DIR" -name ".git" -type d -exec rm -rf {} \; 2>/dev/null || true
find "$BUILD_DIR" -name ".github" -type d -exec rm -rf {} \; 2>/dev/null || true

# Compile lua files.
echo ""
echo "[compile]"

"$LUAC" -v
checkError

find "$BUILD_DIR_LUA" -type f -name "*.lua" | while read luaFile; do

  # Skip files in template directories
  if [[ "$luaFile" == *"/template/"* ]]; then
      echo "skipping template file: $luaFile"
      continue
  fi

	echo "compiling: $luaFile"
	"$LUAC" -s -o "$luaFile" -- "$luaFile"
	checkError
done
checkError

echo ""
echo "[zip]"
ZIP_FILE="$path/plugin-$LIBRARY_NAME.zip"
cd "$BUILD_DIR" > /dev/null
	rm -f "$ZIP_FILE"
	zip -r -x '*.DS_Store' @ "$ZIP_FILE" ./*
cd - > /dev/null

find ./build/plugins/2017.3032/lua/lua_51/plugin -name ".DS_Store" -delete
tar -czvf plugin.data.tgz -C ./build/plugins/2017.3032/lua/lua_51/plugin .

echo ""
echo "[complete]"
echo "Plugin build succeeded."
echo "Zip file located at: '$ZIP_FILE'"
echo "tar file located at: plugin.data.tgz"


echo ""
echo "[uploading to GitHub release]"

# Load environment variables from .env file
if [ -f "$path/.env" ]; then
  echo "Loading GitHub token from .env file"
  source "$path/.env"
fi

# Check if GitHub token is set
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Error: GITHUB_TOKEN environment variable is not set"
  echo "Please set it: export GITHUB_TOKEN=your_personal_access_token"
  exit 1
fi

# Get the latest release ID from kwik5-project-template repository
echo "Fetching latest release information..."
RELEASE_INFO=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/kwiksher/kwik5-project-template/releases/latest")

# Check if we got a valid response
if [[ $RELEASE_INFO == *"message"*"Not Found"* ]] || [[ -z "$RELEASE_INFO" ]]; then
  echo "Error: Could not fetch release information. Check your token permissions."
  exit 1
fi

# Extract the upload URL and release ID
UPLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')
RELEASE_ID=$(echo "$RELEASE_INFO" | grep -o '"id": [0-9]*,' | head -1 | grep -o '[0-9]*')

if [ -z "$UPLOAD_URL" ] || [ -z "$RELEASE_ID" ]; then
  echo "Error: Could not extract upload URL or release ID"
  exit 1
fi

echo "Found latest release ID: $RELEASE_ID"
echo "Uploading plugin.data.tgz..."

# Upload the asset
UPLOAD_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Content-Type: application/gzip" \
  -H "Accept: application/vnd.github.v3+json" \
  --data-binary @plugin.data.tgz \
  "${UPLOAD_URL}?name=plugin.data.tgz")

# Check if upload was successful
if [[ "$UPLOAD_RESPONSE" == *"browser_download_url"* ]]; then
  DOWNLOAD_URL=$(echo "$UPLOAD_RESPONSE" | grep -o '"browser_download_url": "[^"]*' | cut -d'"' -f4)
  echo "Upload successful!"
  echo "Download URL: $DOWNLOAD_URL"
else
  echo "Error uploading asset:"
  echo "$UPLOAD_RESPONSE"
  exit 1
fi