# Build and validation — current source

## Windows installer (2026-11-06)

- CI run 42251672326 (commit ea127f1, `windows-2022`) compiled
  `packaging/windows/installer.iss` with the runner's Inno Setup —
  `Inno Setup Setup Data (6.7.0)` per the setup header.
- Published `SibylControlSetup-0.1.0.exe`, 10,744,248 bytes, SHA-256
  `864ec9aca92de36f8f47f5627babcede8b8d6b4cb070a193ffd4fd9e640370b9`;
  the asset was downloaded and re-hashed locally to the same value.
- `installer-manifest.txt` (also published) lists the 14 packed files with
  their own SHA-256: `sibyl_control.exe`, `flutter_windows.dll`,
  `universal_ble_plugin.dll`, `data\app.so`, `data\icudtl.dat`, the five
  `flutter_assets` manifests plus `NOTICES.Z`, `assets\mark.png`,
  `assets\branding\icon-256.png`, the Material Icons font and
  `shaders\ink_sparkle.frag` — the complete release bundle.
- The setup's `MAINICON` carries 16/24/32/48/64/128/256; the extracted 128 px
  image is byte-identical to `assets/branding` master `icon-128.png`
  (ImageMagick RMSE 0). `VS_VERSION_INFO`: `CompanyName = Sibyl`,
  `FileDescription = Sibyl Control Setup`, `ProductName = Sibyl Control`,
  `FileVersion = 0.1.0`.
- Not verified: the installer has not been run. There is no Windows host and
  no Wine here, and Debian's innoextract (1.9) cannot read an Inno Setup 6.7
  payload, so the install/uninstall flow, the shortcuts and the upgrade path
  are unexercised. The installer is unsigned, so SmartScreen will warn.

## Branding pass (2026-11-05)

Measured, not asserted:

- **Android** (`flutter build apk --debug --target-platform android-arm64`,
  Flutter 3.47.7 — the toolchain this Android project was generated with;
  Gradle capped at 1 worker / 768 MiB / no daemon): BUILD SUCCESSFUL,
  `app-debug.apk` 82,782,866 bytes, sha256 `c662e34d332b21bf…`.
  `aapt2 dump badging`: `application-label:'Sibyl Control'`,
  `icon='res/mipmap-anydpi-v26/ic_launcher.xml'`. The APK carries
  `mipmap-anydpi-v26/ic_launcher{,_round}.xml`, `ic_launcher_foreground.png`
  and `ic_launcher_round.png` at all five densities plus
  `drawable-*/launch_image.png`; `color/app_background` resolves to `#ff0a0d14`
  and is the window background. Adaptive foreground measured on the
  xxxhdpi export: 432x432 canvas, ink 125x219 centred on (216,216), farthest
  ink corner 127 px against the 132 px safe radius.
  Debug-signed preview, not installed on a device.
- **Linux** (Flutter 3.35.4): release build of the shipping entry point, then
  run on Xvfb — the real window reports `_NET_WM_NAME = "Sibyl Control"` and
  carries a `_NET_WM_ICON` property; the bundle contains
  `data/flutter_assets/assets/branding/icon-256.png`. 10 s smoke launch, exit
  124 from the timeout, zero exception lines.
- **Windows** (GitHub Actions `windows-2022`, Flutter 3.35.4, run 42090476603,
  commit d6a062d): build succeeded; the release asset
  `sibyl_control_windows.zip` (12,247,158 bytes) was downloaded and inspected
  with `wrestool`/`icotool`. The exe's icon group holds 16/24/32/48/64/128/256
  entries and the extracted 256 px image is the blue S on the dark plate, not
  the stock Flutter icon. `VS_VERSION_INFO` reads
  `FileDescription = Sibyl Control`, `ProductName = Sibyl Control`.
- Not verified: no device install, no Bluetooth traffic, no light-theme or
  HiDPI pass, and the Linux `.desktop` entry ships as a script rather than an
  installed package.

## UI redesign pass (2026-11-05, Flutter 3.35.4 / Dart 3.9.2)

- `dart analyze lib tool`: No issues found. `dart format`: clean.
- Linux x64 Release, shipping entry point (`lib/main.dart`): built successfully; 10 s smoke launch on Xvfb `DISPLAY=:96`, exit 124 from the intentional timeout, zero exception/error lines in the launch log. No Bluetooth action performed.
- Linux x64 Release, preview entry point (`tool/ui_preview.dart`): built successfully and screenshotted at 1280x720 and 420x860 for all four screens, plus the real app's first-launch screen. Every screenshot was reviewed against the layout checklist; the defects found (chips stretching to full width, header not on the content wrap, absent scrollbar, radio-looking step markers, "no devices found" shown before any scan, copy that named a button that did not exist) were fixed and re-shot.
- The view-model contract (`EarbudViewModel`, `UiSnapshot` and every Ui* class) is unchanged and re-exported from `lib/ui/earbud_app.dart`, so `lib/controller.dart` compiles untouched. Every control gate (`connected && configurationReady && protocol known && idle`) has the same predicate as before; only its presentation changed.
- Not verified: Android and Windows builds were not re-run in this pass, no hardware was connected, and no control packet was sent.

## Earlier source validation

- Dart analyze lib tool: No issues found.
- Standalone offline protocol_check.dart: PASS: 109 offline protocol checks (synthetic fixtures only).
- Linux x64 Release: final source rebuilt successfully (build_linux_final.log). Eight-second UI smoke launch on DISPLAY=:96 emitted renderer initialization and no Dart exception; timeout exit124 intentionally closed the app. No visual widget assertions or Bluetooth actions performed.
- Android ARM64 Debug: Gradle BUILD SUCCESSFUL in40s; app-debug.apk exists. apksigner verify exit0, signer CN=Android Debug. Native Kotlin and plugin compilation completed; not installed or run on a device.
- Android ARM64 release-mode preview: BUILD SUCCESSFUL; APK22,399,537 bytes; apksigner verify exit0, signer CN=Android Debug. R8 disabled after bounded Metaspace exhaustion; no memory cap increase. This is a preview signed with a DEBUG certificate, NOT a production release identity. SHA25683294eb8edb3b4ab65649e81f9aeb03327ee76ef6458703fc019997523a02c31.
- Windows: Flutter runner and WinSock RFCOMM source supplied; no Windows binary built or runtime validated. Run build_windows.ps1 on Windows with Flutter/VisualStudio C++ tools.

## Corrections included in current source
RTK current listening-state event uses0x0C3C;0x0C3B no longer interpreted as state. Short ACK discarded. Cancellation/late-ACK handling, connection epochs, scan timer lifecycle and parser resets hardened. RTK ANC/EQ control remains locked pending complete device capability/group negotiation. No hardware compatibility claim.

## Resource/operational boundaries
No pytest or full test suite. Serial Gradle workers1 heap768MiB, Kotlin in-process; CMake parallel1. No user earphone scanning/connecting or commands sent during development. SDK support packages34/35/36, NDK28.2 and CMake3.22.1 installed using checksum-verified official archives because Java SDK manifest downloads failed. Google Maven mirror support is local build configuration; Android may emit AGP/Kotlin deprecation warnings. Linux binary is an x64 GTK/BlueZ app, not a standalone all-Linux universal executable.

## Remaining completion gap
Three-target SAME UI source is present, but three-platform binary acceptance is NOT complete: Windows needs a Windows build host, product config must be supplied/confirmed for the exact model, and real Bluetooth interoperability remains unverified. Do not represent the package as fully validated across three platforms.
