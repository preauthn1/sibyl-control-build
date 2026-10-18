# Build and validation — current source

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
