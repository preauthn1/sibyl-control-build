$ErrorActionPreference = 'Stop'
# Run on Windows with Flutter and Visual Studio C++ desktop tools installed.
# No tests, device connection or Bluetooth action are performed by this script.
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
dart analyze lib tool
if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed' }
dart tool/protocol_check.dart
if ($LASTEXITCODE -ne 0) { throw 'Offline protocol validation failed' }
$env:CMAKE_BUILD_PARALLEL_LEVEL = '1'
flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
$release = 'build\windows\x64\runner\Release'
if (!(Test-Path "$release\sibyl_control.exe")) { throw 'Expected executable missing' }
New-Item -ItemType Directory -Force dist | Out-Null
Compress-Archive -Path "$release\*" -DestinationPath 'dist\sibyl-control-windows-x64.zip' -Force
Get-FileHash 'dist\sibyl-control-windows-x64.zip' -Algorithm SHA256
