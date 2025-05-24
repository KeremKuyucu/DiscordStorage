[Setup]
AppName=DiscordStorage
AppVersion=v0.1.3-alpha
DefaultDirName={userappdata}\DiscordStorage
DefaultGroupName=DiscordStorage
OutputDir=C:\Users\Kerem\Projects
OutputBaseFilename=DiscordStorage_Installer
Compression=lzma
SolidCompression=yes

[Files]
Source: "C:\Users\Kerem\Projects\StudioProjects\discordstorage\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\Users\Kerem\Projects\StudioProjects\discordstorage\assets\logo.ico"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne kısayol oluştur"; GroupDescription: "Kısayol seçenekleri"; Flags: unchecked
Name: "startmenuicon"; Description: "Başlat menüsüne kısayol oluştur"; GroupDescription: "Kısayol seçenekleri"; Flags: unchecked

[Icons]
Name: "{userdesktop}\DiscordStorage"; Filename: "{app}\discordstorage.exe"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{group}\DiscordStorage"; Filename: "{app}\discordstorage.exe"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"; Tasks: startmenuicon

[Run]
Filename: "{app}\discordstorage.exe"; Description: "DiscordStorage'i Başlat"; Flags: nowait postinstall skipifsilent
