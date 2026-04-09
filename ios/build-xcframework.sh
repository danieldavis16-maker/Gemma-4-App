#!/bin/bash
set -e

# Build llama.cpp xcframework with multimodal (mtmd/clip) support for iOS
# Run this on your Mac: ./build-xcframework.sh

LLAMA_DIR="/tmp/llama-cpp-build"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/Frameworks"

echo "=== Building llama.cpp xcframework with vision support ==="

# Clean previous build
rm -rf "$LLAMA_DIR"

# Clone latest llama.cpp
echo "Cloning llama.cpp..."
git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
cd "$LLAMA_DIR"

# Build for iOS device (arm64)
echo "Building for iOS device (arm64)..."
cmake -B build-ios \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_METAL=ON \
  -DLLAMA_BUILD_COMMON=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF

cmake --build build-ios --config Release --target llama mtmd -j$(sysctl -n hw.ncpu)

# Build for iOS simulator (arm64)
echo "Building for iOS simulator (arm64)..."
cmake -B build-sim \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_METAL=ON \
  -DLLAMA_BUILD_COMMON=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF

cmake --build build-sim --config Release --target llama mtmd -j$(sysctl -n hw.ncpu)

# Find built frameworks/dylibs
echo "Packaging xcframework..."
DEVICE_LIB=$(find build-ios -name "libllama.dylib" -o -name "llama.framework" | head -1)
SIM_LIB=$(find build-sim -name "libllama.dylib" -o -name "llama.framework" | head -1)

if [ -z "$DEVICE_LIB" ] || [ -z "$SIM_LIB" ]; then
  echo "Error: Could not find built libraries. Trying alternative paths..."
  # Try framework output
  find build-ios -name "*.dylib" -o -name "*.framework" | head -20
  find build-sim -name "*.dylib" -o -name "*.framework" | head -20
  exit 1
fi

# Create xcframework
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/llama.xcframework"

xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" \
  -library "$SIM_LIB" \
  -output "$OUTPUT_DIR/llama.xcframework"

echo ""
echo "=== Build complete ==="
echo "xcframework: $OUTPUT_DIR/llama.xcframework"
echo ""
echo "Next steps:"
echo "1. Open Gemma4Chat.xcodeproj in Xcode"
echo "2. Remove old llama.xcframework reference"
echo "3. Drag the new one from Frameworks/ into the project"
echo "4. Set to Embed & Sign"
echo "5. Build and run"
