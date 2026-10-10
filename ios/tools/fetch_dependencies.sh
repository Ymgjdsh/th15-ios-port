#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DEPS=${TH15_DEPENDENCIES:-$ROOT/.local/dependencies}
mkdir -p "$DEPS"
ARCHIVE="$DEPS/SDL3-3.4.2.tar.gz"
EXPECTED=ef39a2e3f9a8a78296c40da701967dd1b0d0d6e267e483863ce70f8a03b4050c
if [ ! -f "$ARCHIVE" ]; then
 curl -fL --retry 3 https://github.com/libsdl-org/SDL/releases/download/release-3.4.2/SDL3-3.4.2.tar.gz -o "$ARCHIVE.pending"
 mv "$ARCHIVE.pending" "$ARCHIVE"
fi
ACTUAL=$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f1)
if [ "$ACTUAL" != "$EXPECTED" ]; then echo "SDL archive checksum mismatch" >&2; exit 1; fi
if [ ! -d "$DEPS/SDL" ]; then
 mkdir -p "$DEPS/SDL"
 tar -xzf "$ARCHIVE" --strip-components=1 -C "$DEPS/SDL"
fi
echo "SDL3 3.4.2 ready in $DEPS/SDL"
