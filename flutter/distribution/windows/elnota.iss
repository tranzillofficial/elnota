#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
[Setup]
AppId={{4A6FB93B-8D0B-43AC-924F-D756D7B120AC}
AppName=ElNota
AppVersion={#AppVersion}
AppPublisher=ElNota
AppPublisherURL=https://elnota.shop
DefaultDirName={autopf}\ElNota
DefaultGroupName=ElNota
OutputDir=output
OutputBaseFilename=ElNota-{#AppVersion}-windows-x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\elnota.exe
[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\ElNota"; Filename: "{app}\elnota.exe"
Name: "{autodesktop}\ElNota"; Filename: "{app}\elnota.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Run]
Filename: "{app}\elnota.exe"; Description: "Launch ElNota"; Flags: nowait postinstall skipifsilent
