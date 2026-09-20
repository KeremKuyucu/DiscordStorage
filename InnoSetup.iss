; -- DiscordStorage Kurulum Betiği / Setup Script --
; Modern Windows uygulamaları için yapılandırılmıştır. / Optimized for modern Windows applications.

; === Temel Bilgiler / Basic Info ===
#define AppName "DiscordStorage"
#ifndef AppVersion
  #define AppVersion "v0.5.0-beta"
#endif
#define AppPublisher "Kerem Kuyucu"
#define AppURL "https://github.com/KeremKuyucu/DiscordStorage"
#define AppExeName "discordstorage.exe"

; === Derleme Ayarları / Build Configuration ===
#define SourcePath "build\\windows\\x64\\runner\\Release"
#define LogoFile "assets\\logo.ico"
#define OutputPath "installers"

[Setup]
AppId={{C6D2D8F6-9634-4A82-A558-75F7A43C21E3}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}

DefaultDirName={userappdata}\{#AppName}
DefaultGroupName={#AppName}

OutputDir={#OutputPath}
OutputBaseFilename={#AppName}_{#AppVersion}_Installer

Compression=lzma2
SolidCompression=yes

WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourcePath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#LogoFile}"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "Ek Kısayollar / Additional Shortcuts:"
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "Ek Kısayollar / Additional Shortcuts:"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\discordstorage"; ValueType: string; ValueName: ""; ValueData: "URL:DiscordStorage Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\discordstorage"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\discordstorage\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\discordstorage\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Flags: uninsdeletekey

[UninstallDelete]
; Kullanıcı ayarlarını veya log dosyalarını kaldır / Delete user settings or logs
Type: filesandordirs; Name: "{userappdata}\{#AppName}\UserSettings"
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{userappdata}\{#AppName}\logs"
