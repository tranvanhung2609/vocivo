; Script generated for Vocivo Flutter Windows App
; Inno Setup Script
#define MyAppName "Vocivo"
#define MyAppPublisher "Vocivo Team"
#define MyAppURL "https://github.com/tranvanhung2609/vocivo"
#define MyAppExeName "vocivo.exe"

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

#ifndef SourceDir
#define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "..\..\build\windows\installer"
#endif

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{8B1D4F1E-7860-4AC4-B09A-1F4F9A680DA6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; PrivilegesRequired=lowest allows standard user install into LocalAppData\Programs without UAC admin prompt.
; PrivilegesRequiredOverridesAllowed=dialog lets users choose between all-users vs current-user if run as admin.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=vocivo-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Check: not WizardSilent
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent
