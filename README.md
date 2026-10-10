<p align="center">
  <img src="docs/port-icon.svg" alt="TH15 iOS port" width="180">
</p>

# TH15 iOS Port

A native iOS port of 東方紺珠伝 ～ Legacy of Lunatic Kingdom by Team Shanghai Alice, using the TH15 1.00b C++ reconstruction, SDL3 and OpenGL ES 3.

The iOS version adds:

- iOS 14+ ARM64 support and an IPA for TrollStore or personal re-signing
- Touch dragging with an optional original-speed limit, an analog joystick with adjustable dead zone, and Z / X / S buttons
- Full-screen landscape and a full-screen portrait playfield with the original score panel moved above it
- Chinese native settings, Auto Bomb, Z Toggle, S Toggle and No Button
- Freely draggable controls, with separate portrait and landscape layouts, save, reset and cancel
- An optional DEV panel and permanent full unlock with the code `ymgjdsh`
- Persistent settings, sandbox saves and replays, background/audio interruption handling and local log export

Game resources are the original Japanese 1.00b version. The native settings are Chinese. This repository contains the source and build tools; original game data and generated font/music files are private local inputs.

## Building

### Dependencies

- macOS with Xcode 14 or a compatible newer Xcode, CMake 3.20+, and Python 3
- Windows with Node.js 22+ and Japanese Windows fonts for the initial GDI font preparation
- Python packages `numpy`, `soundfile>=0.13`, `Pillow`, and `pefile` for resource and icon preparation

### Assets

Prepare fonts once on Windows, using a licensed font environment with MS Gothic and MS Mincho:

```powershell
npm ci --prefix ios/tools/fonts
node ios/tools/fonts/prepare.mjs
python -m pip install numpy "soundfile>=0.13" Pillow pefile
python ios/tools/prepare_assets.py --original "D:/Games/TH15"
python ios/tools/prepare_icon.py --exe "D:/Games/TH15/th15.exe"
```

Copy the private `.local/assets` and `.local/app-icon` directories to the same locations in the Mac checkout. See [ios/ASSETS.md](ios/ASSETS.md) for formats, verification and reuse of prepared resources.

### iOS

```sh
bash ios/tools/fetch_dependencies.sh
TH15_SDK=iphoneos TH15_DIAGNOSTICS=OFF bash ios/build_ios.sh
python3 ios/tools/package_ipa.py \
  .local/build-iphoneos/RelWithDebInfo-iphoneos/th15.app \
  dist/TH15-iOS14-Native-b6.ipa
```

`TH15_BUILD_NUMBER`, `TH15_BUILD_JOBS`, `TH15_ASSETS`, `TH15_DEPENDENCIES` and `TH15_BUILD_DIR` override their defaults. SDL3 is pinned to 3.4.2 and checked against its archive hash. Set `TH15_SDK=iphonesimulator` for simulator builds. The IPA uses ad-hoc signing; ordinary installation requires personal Apple signing and provisioning. Runtime details and diagnostic builds are in [ios/README.md](ios/README.md).

## Controls

Z shoots and confirms, X releases a Bomb and goes back, and S focuses. Move with the joystick or drag the playfield. The joystick keeps tracking the captured finger outside its circle. Double-tap Bomb and two-finger focus are configurable. Swipe to navigate menus, tap to confirm or advance dialogue, two-finger tap to return in menus, and use four fingers to pause in battle. Gear opens settings and the pause button pauses or returns.

Z Toggle and S Toggle keep shooting/focus active after release until the next tap. Opening a panel, pausing, rotating, or leaving gameplay clears the held actions. Menu buttons keep their normal behavior. No Button hides joystick/Z/X/S in combat, keeps gear/pause/DEV and gestures available, and restores menu controls. Enable automatic shooting separately when using No Button if desired.

Auto Bomb is off by default. When an actual collision would hit a vulnerable active player, it invokes that character's original Bomb before hit sound/effects, consumes one Bomb, and preserves the original Bomb effects and invulnerability. It does not predict bullets or restore lost lives. No stock, dialogue, an active Bomb, replay playback, or other original Bomb restrictions prevent activation.

Open **自由调整操作布局** in settings, then drag any control. Portrait and landscape are saved separately. Save commits the draft, reset clears the current orientation, and cancel discards changes. Editing keeps the game paused. **竖屏战斗全屏** controls the portrait score-header/playfield layout.

Enable **开发者功能** to show DEV during ordinary combat. Its panel offers invincibility, maximum score/items/power, lives/Bombs refill, maximize all, and clear bullets/lasers. Invincibility resets on restart. Enter `ymgjdsh` under **输入作弊码解锁全部内容** to save all characters' Extra, practice, spell records and music unlocks.

## Todo

- Complete physical iOS 14 device, controller, performance and long-session testing
- Validate full playthroughs; simulator loading and interface checks do not establish full-game compatibility

See [ios/VALIDATION.md](ios/VALIDATION.md) for completed checks and remaining limits.

## Credits

- [YomotsuHisami/th15](https://github.com/YomotsuHisami/th15), the TH15 1.00b C++ reconstruction by SteinsGateON; the supplied source's [upstream README](docs/UPSTREAM.md) is retained
- Team Shanghai Alice / ZUN for 東方紺珠伝 ～ Legacy of Lunatic Kingdom
- SDL3 for the platform layer; miniaudio and stb for audio/image decoding
- Earlier TH06/TH08/TH10 iOS projects for portrait layout, developer controls and input-policy references

## Assets and licensing

No original game executable, archives, music, generated fonts, replays, saves or IPA are included. Build runnable packages locally from inputs you are entitled to use. The documentation icon is a simple port mark; the private application icon is extracted from the original executable.

Licensing is component-specific: the reconstruction and port source use the [MIT license](LICENSE); SDL3, miniaudio and stb retain their notices under [ios/licenses](ios/licenses) and the bundled component headers. Original game resources and Windows fonts retain their respective rights. Do not apply the source license to those resources.
