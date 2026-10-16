# TH15 iOS Build 6 validation

Date: 2026-10-11. Native UIKit / SDL3 / GLES3, original Japanese 1.00b game data, Chinese native settings.

## Completed

- Simulator and ARM64 device targets compile with minimum iOS 14.0.
- Eight native checks pass: touch/fixed cadence, joystick, 120 overlapping pause orders, portrait mapping, Toggle/layout coordinates, Auto Bomb eligibility and single consumption, real PlayerMotion drag limits, and saved full-unlock records.
- Injected actual `PlayerCollision.circle` checks pass for Reimu, Marisa, Sanae and Reisen. Each starts its original Bomb, stock changes 3 → 2, later live collision queries do not hit or consume again, and disabled/empty-stock cases enter ordinary deathbomb state. Reimu has one frame of bridge protection because her original shield begins in the next Bomb callback. No hit sound/effect path runs on successful activation.
- Resource preparation works from the original archive/music inputs. All 13 regenerated font binaries plus CP932 and blend tables match the previous resources. All 18 converted tracks pass decoded sample counts and preserve loop positions. Ogg container serial numbers can change between conversions.
- Device IPA passes archive CRC, resource hashes, icon, ARM64, iphoneos platform, Mach-O and plist minimum iOS 14.0, diagnostics OFF, ad-hoc signature and absence of browser/Windows runtimes.
- Independently downloaded Windows copy passes the IPA/manifest/resource verification.
- Mac and Windows desktop copies have the same verified SHA256.
- README and application icons use the image extracted from the original `th15.exe`.

## UIKit interface checks

Environment: Xcode 14, iPad mini 5 simulator, iPadOS 16.0.

| Test | Result | Coverage |
| --- | --- | --- |
| `testAutoBombTogglesAndLayout` | Success, 492.521 seconds | Auto Bomb setting; Z/S latch and release; opening settings clears held actions and resumes combat; portrait/landscape layout dragging and saving; cancel; restart persistence; No Button hides joystick/Z/X/S while retaining settings/pause; editing hidden controls; reset; ordinary menu confirmation |
| `testDeveloperDragAndUnlock` | Success, 231.588 seconds | Drag speed and DEV settings; invincibility, maximize and clear-bullet actions; original player state updated; invincibility clears on restart; full wrong/correct code entry; unlock error/success; saved music/Extra unlocks; Extra character menu; developer controls hide after disabling |
| `testMenus` | Success, 821.845 seconds | Replay, Player Data, Music Room and Manual entry/return; Options volume adjustment; Key Config mapping and save; start, mode, difficulty and character menus; return from character selection |
| `testControlsSettingsAndRotation` | Success, 103.296 seconds | Joystick finger dragged outside its circle; dead-zone and sensitivity sliders; applied dead-zone range; landscape/portrait rotation; dead-zone setting and slider value retained after restart |

Portrait and landscape editor screenshots, native settings, DEV, cheat-code entry and No Button screenshots were inspected. The portrait HUD remains above the full-width playfield; No Button removes action controls while retaining settings and pause. The portrait setting is labelled only “竖屏战斗全屏”, without “TH06 布局”.

The first controls/rotation regression expected exactly `0.40` after XCTest dragged a physical slider to a normalized target of `0.8`. UIKit actually applied and saved approximately `0.4243`, displayed as `0.42`. The test now checks that the setting changes into the expected range and survives restart, rather than requiring an exact automation drag coordinate. Its completed rerun passed. The combined regression result retains that initial test failure; the two other tests in that result succeeded, and the successful controls rerun is saved separately. All four interface tests above have completed successful results.

Local evidence: `ui-b6-final.xcresult` (Auto Bomb/Toggle/layout), `ui-b6-final-regression.xcresult` (menus/DEV/unlock), and `ui-b6-controls-final.xcresult` (corrected controls/rotation). Exported summaries and screenshots are retained privately under `.local/reports/`; test logs and game resources are not published.

## Delivered artifact

`TH15-iOS14-Native-b6.ipa`: 177,015,007 bytes.

```text
SHA256: f5c2252b58f5e32a37becd5d4c85dee998bd7c61afdc653ab2d6914c75af96d2
Executable SHA256: c5ef57856abb395227428e820ac2639039432dc2a821aa134a0318e86e7a2324
```

The device build was produced independently from the public source at commit `174a6df48ea33abf7bc654c27eb19ee6cffea6de`, with private game assets supplied separately. All 547 tracked source files were checked against that revision before building. Later validation-document and UI-test changes do not change the delivered game executable. No game archive, generated font/music pack, original executable, saved data or IPA is stored in the public repository; only the original icon preview is included.

The package uses ad-hoc signing for TrollStore or personal Apple re-signing; it is not an App Store installation package.

## Scope

Collision checks inject geometry through the real collider and original Bomb services; they do not establish a natural bullet-pattern playthrough. Interface/stage checks use diagnostic invulnerability. No iOS 14 physical device, full playthrough, physical controller or long-session performance acceptance has been completed. Build and simulator verification cannot guarantee perfect behavior on every device.

Historical Build 5 evidence is retained in [docs/VALIDATION-B5.md](../docs/VALIDATION-B5.md).
