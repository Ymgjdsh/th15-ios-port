# TH15 iOS Build 6 validation

Date: 2026-10-11. Native UIKit / SDL3 / GLES3, original Japanese 1.00b game data, Chinese native settings.

## Completed

- Simulator and ARM64 device targets compile with minimum iOS 14.0.
- Eight native checks pass: touch/fixed cadence, joystick, 120 overlapping pause orders, portrait mapping, Toggle/layout coordinates, Auto Bomb eligibility and single consumption, real PlayerMotion drag limits, and saved full-unlock records.
- Injected actual `PlayerCollision.circle` checks pass for Reimu, Marisa, Sanae and Reisen. Each starts its original Bomb, stock changes 3 → 2, later live collision queries do not hit or consume again, and disabled/empty-stock cases enter ordinary deathbomb state. Reimu has one frame of bridge protection because her original shield begins in the next Bomb callback. No hit sound/effect path runs on successful activation.
- Resource preparation works from the original archive/music inputs. All 13 regenerated font binaries plus CP932 and blend tables match the previous resources. All 18 converted tracks pass decoded sample counts and preserve loop positions. Ogg container serial numbers can change between conversions.
- Device IPA passes archive CRC, resource hashes, icon, ARM64, iphoneos platform, Mach-O and plist minimum iOS 14.0, diagnostics OFF, ad-hoc signature and absence of browser/Windows runtimes.
- Independently downloaded Windows copy passes the IPA/manifest/resource verification.

Interface checks are being completed before final delivery; this record will be updated with their actual results.

## Scope

Collision checks inject geometry through the real collider and original Bomb services; they do not establish a natural bullet-pattern playthrough. Interface/stage checks use diagnostic invulnerability. No iOS 14 physical device, full playthrough, physical controller or long-session performance acceptance has been completed. Build and simulator verification cannot guarantee perfect behavior on every device.

Historical Build 5 evidence is retained in [docs/VALIDATION-B5.md](../docs/VALIDATION-B5.md).
