#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="/Applications/CMake.app/Contents/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
SDK=${TH15_SDK:-iphoneos}
case "$SDK" in
 iphoneos) ARCH=arm64;;
 iphonesimulator) ARCH=$(uname -m);;
 *) exit 2;;
esac
BUILD=${TH15_BUILD_DIR:-$ROOT/.local/build-$SDK}
cmake -S "$ROOT/ios" -B "$BUILD" -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$SDK" --show-sdk-path)" -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DTH15_DEPENDENCIES="${TH15_DEPENDENCIES:-$ROOT/.local/dependencies}" -DTH15_ASSETS="${TH15_ASSETS:-$ROOT/.local/assets}" -DTH15_BUILD_NUMBER="${TH15_BUILD_NUMBER:-7}" -DTH15_DIAGNOSTICS="${TH15_DIAGNOSTICS:-OFF}" -DTH15_SDL_LIBRARY="${TH15_SDL_LIBRARY:-}"
cmake --build "$BUILD" --config RelWithDebInfo --target th15 -- -quiet -jobs "${TH15_BUILD_JOBS:-4}"
cmake -E copy_directory "${TH15_ASSETS:-$ROOT/.local/assets}" "$BUILD/RelWithDebInfo-$SDK/th15.app/assets"
