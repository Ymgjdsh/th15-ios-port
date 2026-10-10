#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/.local/native-checks"
mkdir -p "$OUT"
for name in input joystick lifecycle portrait controls autobomb; do
 xcrun clang++ -std=c++17 -O2 "$ROOT/ios/tests/$name.cpp" -o "$OUT/$name"
 "$OUT/$name"
done
xcrun clang++ -std=c++17 -O2 "$ROOT/ios/tests/drag.cpp" "$ROOT/th15_web/cpp/game/PlayerMotion.cpp" -o "$OUT/drag"
"$OUT/drag"
xcrun clang++ -std=c++17 -O2 "$ROOT/ios/tests/unlock.cpp" "$ROOT/th15_web/cpp/game/RecordStore.cpp" "$ROOT/th15_web/cpp/game/ScoreFile.cpp" "$ROOT/th15_web/cpp/game/Lzss.cpp" "$ROOT/th15_web/cpp/game/ResourceCrypt.cpp" -o "$OUT/unlock"
"$OUT/unlock"
