; Inno Setup script for Sibyl Control.
;
; Built in CI after `flutter build windows --release`:
;   iscc /DMyAppVersion=0.1.0 packaging\windows\installer.iss
;
; It lives outside windows\, because CI deletes and regenerates that whole
; directory with `flutter create`. Defaults assume the script sits in
; <repo>\packaging\windows and the release output is at
; <repo>\build\windows\x64\runner\Release.

#define MyAppName "Sibyl Control"
#define MyAppPublisher "Sibyl"
#define MyAppExeName "sibyl_control.exe"
#define MyAppURL "https://github.com/preauthn1/sibyl-control-build"

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
; Keep this GUID stable: it is how Windows recognises an upgrade.
AppId={{2C221BEF-AF06-4565-90FB-98ED16B08F3E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; No driver, no service, nothing outside the install directory: a per-user
; install needs no elevation, and the user may still choose all-users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=SibylControlSetup-{#MyAppVersion}
; ISCC writes every packed file here, so CI can prove what went in.
OutputManifestFile={#OutputDir}\manifest.txt
SetupIconFile=..\..\assets\branding\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
AllowNoIcons=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release bundle: the exe, flutter_windows.dll, the plugin
; DLLs and data\ (assets and icudtl.dat).
Source: "{#SourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes nothing else into the install directory, but a crash log can
; land here; remove the directory only if it is empty of user files.
Type: dirifempty; Name: "{app}\data"
Type: dirifempty; Name: "{app}"
