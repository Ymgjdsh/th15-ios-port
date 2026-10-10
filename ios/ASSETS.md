# Private TH15 inputs

Use the original Japanese TH15 1.00b installation containing `th15.dat`, `thbgm.dat` and `th15.exe`. The executable is read only to extract its icon; it is never launched by these preparation tools.

## Fonts (Windows)

Install Node.js 22+ and make the licensed Japanese Windows font environment available (MS Gothic and MS Mincho; the selected face is recorded). Run `npm ci --prefix ios/tools/fonts`, then `node ios/tools/fonts/prepare.mjs`. An optional final argument selects the output directory. The tool records the original 13 CreateFont parameters in `definitions.json`, measures GDI ARGB4444 coverage and writes `font0.bin`–`font12.bin`, `cp932.bin`, `blend4444.bin`, and a hash manifest into `.local/assets/fonts`.

These are private generated font data, not bundled Microsoft font files. The native runtime reads T15G-v3 bitmaps and does not require Windows or font rasterization on the device. A different Windows font environment may change raster results; the manifest records the selected faces and available font hashes.

## Game and music

Install Python packages `numpy` and `soundfile>=0.13`. Run:

```sh
python ios/tools/prepare_assets.py --original /path/to/TH15
```

The tool copies the original archive, reads `thbgm.fmt` from it, and encodes 18 music tracks from `thbgm.dat`. It verifies PCM format, decoded sample counts and original loop positions. Vorbis compression is lossy; the frame counts and loop offsets remain exact. The resulting `.local/assets` contains 36 files plus its SHA256 manifest. To reuse measured fonts, pass `--fonts /path/to/prepared/fonts`. To reuse a previously verified music directory, pass `--prepared-music /path/to/music`; its layout hash, source size and every encoded track hash are checked. `--output` selects a dedicated private directory.

## Icon (Windows or macOS)

Install `Pillow` and `pefile`, then run:

```sh
python ios/tools/prepare_icon.py --exe /path/to/TH15/th15.exe
```

This writes the extracted icon, AppIcon catalog, and provenance manifest under `.local/app-icon`. No redrawing of the game icon occurs. If the executable has multiple icon groups, the tool lists them; select one with `--group` and optionally `--language`.

## Transfer and build

Copy `.local/assets` and `.local/app-icon` into the Mac checkout without committing them. Build with `ios/build_ios.sh`; `TH15_ASSETS` can select another resource directory. `TH15_ICON_CATALOG` is a CMake cache setting for an alternate `.xcassets` catalog. The package tool checks every resource hash, all 18 tracks, all 13 fonts, the icon catalog, ARM64, device platform, minimum iOS 14 and diagnostics OFF, then signs ad-hoc and creates an IPA plus a manifest. `verify_artifact.py` independently checks a transferred IPA against that manifest.

Original resources, generated font/music data, packages, local caches and personal save files are excluded from public source control. Resource preparation requires rights to the original game and the chosen font environment.
