# Build and validation — current source

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
