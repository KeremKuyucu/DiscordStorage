## 📦 Version 0.5.0-beta – Windows Desktop Evolution & Security Upgrade

### 🚀 Changes

* **Windows Desktop Architecture Transition:**
  Transitioned DiscordStorage into a dedicated, optimized Windows desktop application. Removed legacy Android code, Android manifests, Gradle configurations, and mobile permissions to deliver a fast and native desktop experience.

* **Custom URL Protocol (`discordstorage://`) & Deep Linking:**
  Added `ProtocolService` to register the `discordstorage://` custom URI scheme in the Windows Registry (HKCU) without requiring administrator privileges. The app now parses Discord snowflake message IDs (17–20 digits) directly from CLI arguments or links and prompts for download upon launch.

* **Hardware-Tied Windows DPAPI Security:**
  Replaced third-party secure storage packages with native Windows Data Protection API (DPAPI) via Dart FFI (`CryptProtectData` and `CryptUnprotectData` via `Crypt32.dll` and `kernel32.dll`). Bot tokens and sensitive data are encrypted with the active Windows user master key, eliminating plaintext credentials on disk. Existing plaintext tokens are automatically upgraded to DPAPI-encrypted storage.

* **Native Windows Notifications & Throttling:**
  Replaced mobile-centric notifications with `local_notifier` for native Windows desktop notifications. Implemented progress throttling (rate-limiting updates to 3 seconds or a minimum 15% progress delta) and silent progress updates during uploads and downloads to prevent notification sound spam.

* **Stream-Based SHA-256 Hashing (OOM Prevention):**
  Refactored `FileHash` to use byte stream pipelines (`openRead()`) instead of loading entire files into memory (`readAsBytes()`). This resolves Out-of-Memory (OOM) crashes and system freezes when processing multi-gigabyte files.

* **Revamped Logs Viewer & Live Stream:**
  Redesigned the `LogsPage` UI with live log streaming (auto-refresh every 3s), search filtering, log level filtering (Debug, Info, Warn, Error, Verbose), compact and detailed display modes, clipboard copying, and shortcut buttons to open logs directly in Notepad or reveal the file in Windows Explorer.

* **Thread-Safe Log Persistence:**
  Relocated log storage from the user's Documents folder to `%APPDATA%\DiscordStorage\logs\`. Implemented an asynchronous serialization write queue with explicit flush operations to eliminate file lock collisions, along with automatic cleanup of legacy log files.

* **Telemetry Service Integration:**
  Replaced legacy analytics with a lightweight, privacy-respecting `TelemetryService` featuring once-per-session deduplication, configurable network timeouts, and automatic platform detection.

* **Streamlined Dependencies & Packaging:**
  Removed bulky dependencies (`markdown`, `flutter_html`, `device_info_plus`, `permission_handler`, `flutter_secure_storage`). Replaced HTML rendering in the update checker dialog with native `SelectableText` and added a 'Dismiss' action.

* **Automated Windows Build & Deployment Pipeline:**
  Introduced comprehensive PowerShell build and deployment scripts (`build.ps1`, `build.bat`), modern Inno Setup installer packaging (`InnoSetup.iss`) with protocol association and start menu/desktop shortcuts, and automated code signing via `signtool`.

### 🐛 Bug Fixes

* Fixed return value semantics in `FileDownloader.fileDownload` to return the actual byte count on success and `-1` on failure (previously returned `1` on error, breaking downstream error detection in `file_merger.dart`).
* Fixed file path concatenation in `main/screen.dart` when handling temporary download files by using `path.join` instead of raw string addition.
* Fixed string interpolation syntax error in `Filespliter` (`$SettingsService.createdWebhook` -> `${SettingsService.createdWebhook}`) that corrupted generated webhook link headers.
* Updated `DragTarget` handlers to modern Flutter specifications (`onAcceptWithDetails`, `onWillAcceptWithDetails`) and replaced deprecated `withOpacity` calls with `withValues(alpha: ...)`.
* Added missing mounted checks (`if (!context.mounted) return;` / `if (!mounted) return;`) across UI dialogs, snackbars, and navigation callbacks to prevent context exceptions.
* Fixed an unhandled exception in `SettingsService` by validating that the bot token and guild ID are configured before attempting to create the storage channel.

### ⚠️ Breaking Changes (if any)

* **Dropped Android Platform Support:** DiscordStorage is now exclusively focused on Windows Desktop. Android build artifacts, manifest files, and mobile-specific permissions have been removed.
* **Windows DPAPI Token Encryption:** Bot tokens are encrypted using Windows DPAPI tied to the local Windows user account. Profile data copied to a different user account or machine cannot be decrypted and will require re-entering the bot token.

---

## 📦 Sürüm 0.5.0-beta – Windows Masaüstü Dönüşümü ve Güvenlik Güncellemesi

### 🚀 Değişiklikler

* **Windows Masaüstü Mimarisine Geçiş:**
  DiscordStorage, tamamen Windows masaüstüne odaklanan bağımsız bir masaüstü uygulamasına dönüştürüldü. Eski Android kaynakları, Android bildirimleri, Gradle yapılandırmaları ve mobil izinleri kaldırılarak optimize bir masaüstü deneyimi sağlandı.

* **Özel URL Protokolü (`discordstorage://`) ve Derin Bağlantı (Deep Linking):**
  Yönetici izni gerektirmeden Windows Kayıt Defteri'ne (HKCU) `discordstorage://` protokolünü kaydeden `ProtocolService` eklendi. Uygulama, komut satırı argümanları veya web bağlantıları üzerinden gelen 17–20 haneli Discord snowflake mesaj kimliklerini (ID) otomatik yakalar ve açılışta doğrudan indirme onayı sunar.

* **Windows DPAPI ile Donanım/Kullanıcı Tabanlı Şifreleme:**
  Harici güvenli depolama paketleri yerine Dart FFI üzerinden Windows Data Protection API (DPAPI - `CryptProtectData` ve `CryptUnprotectData`) entegre edildi. Discord bot tokeni ve hassas yapılandırma verileri Windows kullanıcı anahtarıyla şifrelenir, diskte asla düz metin olarak saklanmaz. Mevcut düz metin tokenler otomatik olarak DPAPI formatına yükseltilir.

* **Yerel Windows Bildirimleri ve Bildirim Sınırlama (Throttling):**
  Mobil bildirim kütüphanesi yerine `local_notifier` servisine geçilerek yerel Windows masaüstü bildirimleri sağlandı. Dosya yükleme ve indirme işlemlerinde ses ve bildirim kirliliğini engellemek amacıyla akıllı bildirim sınırlaması (throttling - 3 sn veya en az %15 ilerleme farkı) ve sessiz ilerleme bildirimleri uygulandı.

* **Akış (Stream) Tabanlı SHA-256 Hash Hesaplama (Bellek Koruması):**
  `FileHash` servisi tüm dosyayı belleğe yüklemek (`readAsBytes`) yerine akış (`openRead`) boru hattı üzerinden hash hesaplayacak biçimde yenilendi. Bu sayede gigabaytlarca büyüklükteki dosyalarda bellek yetersizliği (OOM) ve uygulamanın kilitlenmesi önlendi.

* **Yenilenen Log Görüntüleyici ve Canlı İzleme:**
  `LogsPage` arayüzü modernleştirildi: Canlı log akışı (3 saniyede bir otomatik yenileme), metin arama, log seviyesine göre filtreleme (Debug, Info, Warn, Error, Verbose), kompakt ve ayrıntılı görünüm seçenekleri, log panosu kopyalama, Not Defteri (`notepad.exe`) ile açma ve Dosya Gezgini'nde konumu gösterme işlevleri eklendi.

* **İş Parçacığı Güvenli Log Altyapısı:**
  Log dosyaları kullanıcının Belgeler klasöründen `%APPDATA%\DiscordStorage\logs\` dizinine taşındı. Asenkron kuyruk (`_writeQueue`) ve atomik yazma (`flush: true`) ile dosya kilitlenme çakışmaları çözüldü; Belgeler klasöründeki eski loglar otomatik temizlendi.

* **Hafif Telemetri Servisi:**
  Eski analitik yapısı kaldırılarak oturum başına tekil gönderim, istek zaman aşımı yönetimi ve platform tespiti sağlayan hafif `TelemetryService` sistemine geçildi.

* **Bağımlılık Temizliği ve Paket Optimizasyonu:**
  Kullanılmayan ve ağır paketler (`markdown`, `flutter_html`, `device_info_plus`, `permission_handler`, `flutter_secure_storage`) projeden çıkarıldı. Güncelleme denetleyicisindeki HTML arayüzü hafif `SelectableText` ile değiştirildi ve 'Kapat' (Dismiss) butonu eklendi.

* **Otomatik Windows Derleme ve Dağıtım Hattı:**
  Kapsamlı PowerShell derleme betikleri (`build.ps1`, `build.bat`), protokol kaydı ve başlat menüsü/masaüstü kısayollarını yöneten modern Inno Setup kurulum betiği (`InnoSetup.iss`) ile `signtool` tabanlı dijital kod imzalama otomasyonu entegre edildi.

### 🐛 Hata Düzeltmeleri

* `FileDownloader.fileDownload` metodundaki durum kodu mantığı düzeltildi; başarılı indirmelerde indirilen bayt sayısı, hatalarda `-1` döndürülerek `file_merger.dart` içindeki hata tespit mekanizması onarıldı (eskiden hata durumunda `1` döndüğünden hatalar tespit edilemiyordu).
* `main/screen.dart` dosyasında geçici indirme dosyası yolu oluşturulurken oluşan metin birleştirme hatası `path.join` kullanılarak düzeltildi.
* `Filespliter` servisinde webhook link başlığının bozulmasına yol açan `$SettingsService.createdWebhook` yazım hatası `${SettingsService.createdWebhook}` olarak düzeltildi.
* Dosya ve klasör sürükle-bırak işlemleri (`DragTarget`) modern Flutter standartlarına (`onAcceptWithDetails`, `onWillAcceptWithDetails`) güncellendi ve kullanımdan kalkan `withOpacity` yerine `withValues(alpha: ...)` fonksiyonu uygulandı.
* Asenkron diyalog, snackbar ve navigasyon işlemlerinde `context` kullanımından kaynaklı hataları önlemek amacıyla eksik `mounted` kontrolleri eklendi.
* `SettingsService` üzerinde henüz bot tokeni veya sunucu kimliği tanımlanmamışken Discord API'sinden depolama kanalı sorgulanması kaynaklı istisnalar engellendi.

### ⚠️ Kırıcı Değişiklikler (varsa)

* **Android Desteği Kaldırıldı:** DiscordStorage artık sadece Windows Masaüstü ortamında çalışan bir uygulamadır. Android kaynak kodları, bildirim izinleri ve Gradle bağımlılıkları tamamen kaldırılmıştır.
* **Windows DPAPI Şifreleme:** Bot tokeni artık çalıştırılan Windows kullanıcı hesabına bağlı DPAPI ile şifrelenir. Başka bir kullanıcı hesabına veya farklı bir bilgisayara aktarılan ayar verileri çözülemez ve bot tokeninin yeniden girilmesi gerekir.

---

# Emoji Referansı / Emoji Reference

| Emoji | Kullanım / Usage |
|-------|------------------|
| 📦 | Sürüm başlığı / Version header |
| 🚀 | Yeni özellikler / New features |
| 🐛 | Hata düzeltmeleri / Bug fixes |
| ⚠️ | Kırıcı değişiklikler / Breaking changes |
| 🔒 | Güvenlik / Security |
| ⚡ | Performans / Performance |
| 🎨 | UI/UX değişiklikleri / UI/UX changes |
| 🔧 | Yapılandırma / Configuration |
| 📝 | Dokümantasyon / Documentation |
| 🌐 | Yerelleştirme / Localization |
