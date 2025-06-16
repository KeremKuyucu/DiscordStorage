; // -- DiscordStorage Kurulum Betiği --
; // Bu betik, modern Windows uygulamaları için en iyi uygulamalar kullanılarak iyileştirilmiştir.
; // - Sabit dosya yolları kaldırılarak taşınabilirlik sağlandı.
; // - Uygulama kimliği ve yayıncı bilgileri gibi önemli meta veriler eklendi.
; // - Kurulum sihirbazı modern bir görünüme kavuşturuldu.
; // - Temiz bir kaldırma işlemi için ek yönergeler eklendi.

; // --- Temel Uygulama Bilgileri ---
; // Bu değerleri her yeni sürümde veya projede kolayca güncelleyebilirsiniz.
#define AppName "DiscordStorage"
#define AppVersion "v0.1.7-alpha"
#define AppPublisher "Kerem Kuyucu" ; // Veya şirket adınız
#define AppURL "https://github.com/KeremKuyucu/DiscordStorage"
#define AppExeName "discordstorage.exe"

; // --- Derleme Ayarları ---
; // Projenizin yerel dosya yapısına göre bu yolları düzenleyin.
; // Betiğin, proje ana dizininde olduğunu varsayarak göreceli yollar kullanmak en iyisidir.
#define SourcePath "build\windows\x64\runner\Release"
#define LogoFile "assets\logo.ico"
#define OutputPath "installers" ; // Derlenmiş kurulum dosyalarının kaydedileceği klasör

[Setup]
; AppId, uygulamanızın Windows tarafından benzersiz olarak tanınmasını sağlar.
; Bu, özellikle güncellemeler ve kaldırma işlemleri için kritik öneme sahiptir.
; Yeni bir proje için https://www.guidgenerator.com/ adresinden yeni bir GUID oluşturun.
AppId={{C6D2D8F6-9634-4A82-A558-75F7A43C21E3}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}

; {localappdata} kullanmak, kullanıcı profiliyle birlikte ağda gezinmeyen
; uygulama verileri için standart bir yaklaşımdır. Bu, daha hızlı ve daha güvenilirdir.
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}

; Kurulum dosyasının adını sürüm numarasıyla birlikte oluşturmak daha düzenlidir.
OutputDir={#OutputPath}
OutputBaseFilename={#AppName}_{#AppVersion}_Installer

; Bu ayarlar kurulum dosyasını küçültür.
Compression=lzma2
SolidCompression=yes

; Modern bir sihirbaz görünümü sunar.
WizardStyle=modern

; Uygulama yönetici hakları gerektirmiyorsa 'lowest' kullanmak en güvenlisidir.
; Bu, UAC (Kullanıcı Hesabı Denetimi) istemlerini önler.
PrivilegesRequired=lowest

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Files]
; Kaynak yolları için sabit disk adresleri yerine yukarıda tanımlanan değişkenleri (#define) kullanıyoruz.
; Bu sayede betik, farklı bilgisayarlarda ve otomasyon sistemlerinde sorunsuz çalışır.
Source: "{#SourcePath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#LogoFile}"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
; Görev tanımları daha açıklayıcı ve gruplandırılmış halde.
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "Ek Kısayollar:";
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "Ek Kısayollar:"; Flags: unchecked

[Icons]
; İsimlerde {#AppName} değişkenini kullanmak, uygulama adı değiştiğinde
; her yeri tek tek düzeltme zahmetinden kurtarır.
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\logo.ico"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: quicklaunchicon

[Run]
; Kullanıcıya kurulum sonunda uygulamayı başlatma seçeneği sunar.
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Uygulama kaldırıldığında geride kalan kullanıcı verilerini veya log dosyalarını temizlemek için kullanılır.
; Örneğin, uygulamanızın oluşturduğu bir ayar klasörünü temizlemek için aşağıdaki satırın yorumunu kaldırıp düzenleyebilirsiniz.
; Type: filesandordirs; Name: "{localappdata}\{#AppName}\UserSettings"