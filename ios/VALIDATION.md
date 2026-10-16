# TH15 iOS Build 7 validation

Date: 2026-10-16. Native UIKit / SDL3 / GLES3, iOS 14.0 minimum, original Japanese 1.00b assets and Chinese settings.

## Fixes

- Reisen's barrier collision briefly leaves the player in pending-hit state 4. Previously the input adapter cleared its primary drag whenever movement was unavailable. An existing drag now stays captured during this pending state, outputs no movement while blocked, and resumes after the original barrier/deathbomb recovery. Touch motion during the blocked interval rebases its origin. Lift/cancel, committed death, disabled gameplay, arrows, rotation and panels still release input.
- The original complete canvas is fitted at 4:3 for menus and landscape. Portrait combat fits the original 384:448 playfield with the original HUD split above it. Both HUD columns preserve their source aspect; the shorter right column leaves padding below. Insets and actual UIKit window bounds determine the available area on iPhone/iPad. Remaining space is black, with no cropping or independent X/Y stretching.
- The native host updates source and destination together before event processing and after each logic step. Drawing and touch coordinate conversion use that same viewport across scene changes, settings and rotation.

## Completed checks

- ARM64 device and simulator builds succeed, minimum iOS 14.0, device diagnostics OFF.
- Eight native checks pass, including pending-hit drag retention/recovery/release in both speed modes and existing input, joystick, lifecycle, Toggle, Auto Bomb, PlayerMotion and unlock checks.
- Aspect/safe-area and equal-axis touch mapping checks cover iPad, iPad Pro, notched iPhone, iPhone SE and compact phone sizes in both orientations, ordinary canvas and portrait combat.
- In-game diagnostic collision check passes: actual Reisen original Bomb and `PlayerCollision.circle`, all three shield charges consumed, life returns to active, same held finger moves again after every hit, limited and unlimited modes, and release stops dragging. This check uses controlled collision injection, not a natural full-game playthrough.
- iPhone 14 / iOS 16.0 `testAspectAndTouch` succeeds (195.756 seconds): portrait/landscape battle and title, actual touch displacement, native settings and screenshots.
- iPad mini 5 / iPadOS 16.0 `testAspectAndTouch` succeeds (151.594 seconds): exact canvas/playfield aspect, native settings, actual touch drag displacement, battle landscape/portrait, title landscape/portrait, screenshots.

The first iPad UI attempts used a short drag/hold that did not produce a consumed movement sample in the slow simulator. The completed test holds for two seconds and waits for observed displacement; its result passed. Initial failed results are preserved privately and are not counted as successes.

## Artifact

`TH15-iOS14-Native-b7.ipa`, 177,016,046 bytes, ARM64, bundle `org.th15.native`, version 1.0.0 / build 7, minimum iOS 14.0.

- IPA SHA256: `34a41b33edf50cd089e8fea6b9931f0f46b67cfef60c4622ad8fa439ddd1203f`
- Executable SHA256: `57c2121b9ade5af85a492194e610a5c874812fd66433aa2ce5e3837459c547ca`
- Packaging and independent Windows artifact verification pass: signatures, ARM64 / iPhoneOS / minimum OS metadata, diagnostics disabled, original executable icon, 36 resource-file hashes, ZIP integrity. Includes 18 music tracks and 13 fonts. Requires TrollStore or re-signing for installation.
- Delivered with manifest and installation notes to the Mac and Windows desktops.

## Scope

No iOS 14 physical device, full playthrough, physical controller or long-session performance acceptance has been completed. Simulator input and controlled collision checks do not guarantee behavior on all physical devices. Game assets remain private; the public repository contains source, build tools and the original icon preview only.

Historical validation: [Build 6](../docs/VALIDATION-B6.md), [Build 5](../docs/VALIDATION-B5.md).
