## 📦 Version 0.5.0-beta – Transition to Dedicated Windows Desktop Platform & Enhanced Security Architecture

### 🚀 Changes

* **Platform Architecture & Mobile Deprecation:**
  - Fully transitioned to a dedicated Windows desktop application by removing all legacy Android assets, Gradle configurations, permissions, and build scripts.
  - Streamlined the codebase to focus completely on robust Windows shell support, deep links, and desktop-first workflows.

* **Security & Token Encryption:**
  - Introduced `SecureStorageService` leveraging Windows DPAPI (`CryptProtectData` / `CryptUnprotectData`) via Dart FFI for secure, user-bound token and credential encryption.

* **Protocol & URI Scheme Integration:**
  - Implemented `ProtocolService` for registering the custom `discordstorage://` URI scheme, enabling CLI arguments parsing and seamless deep-linking to Discord message IDs.

* **Desktop Notifications System:**
  - Migrated notification delivery to `local_notifier`, incorporating progress throttling and smart sound suppression during heavy file transfers to prevent audio spam.

* **Stream-Based File Hashing & Performance:**
  - Refactored `FileHash` to use stream-based hashing (`openRead`), eliminating Out-Of-Memory (OOM) errors and significantly lowering memory footprint when processing multi-gigabyte files.

* **Logging & UI Improvements:**
  - Overhauled `LogsPage` UI with live streaming log output and advanced search/filtering capabilities.
  - Relocated log file storage to `%APPDATA%\DiscordStorage\logs\` with fixed Windows Explorer folder navigation.

* **Privacy-Respecting Telemetry:**
  - Replaced legacy analytics systems with a transparent, privacy-respecting `TelemetryService`.

* **Build Scripts & CI/CD Packaging:**
  - Added automated build (`build.ps1`, `build.bat`), deployment scripts, and updated InnoSetup (`InnoSetup.iss`) installer configuration for effortless distribution.

* **Documentation & Localization:**
  - Overhauled the `README.md` with comprehensive technical architecture documentation and added complete Turkish translation (`README.tr.md`).

### 🐛 Bug Fixes:

* **FileDownloader:** Fixed byte count return semantics to ensure accurate download progress tracking.
* **UI & Layout:** Updated DragTarget implementation to adhere to modern specifications and enforced mounted context safety checks across asynchronous operations.
* **Link Generator:** Fixed string interpolation bugs within the Discord webhook link generator.

### ⚠️ Breaking Changes (if any):

* Dropped Android support entirely; this application is now strictly a Windows Desktop client.
* Stored credentials must be re-initialized due to the migration to Windows DPAPI-encrypted secure storage.

---

## 📦 Sürüm 0.5.0-beta – Özel Windows Masaüstü Platformuna Geçiş ve Gelişmiş Güvenlik Mimarisi

### 🚀 Değişiklikler

* **Platform Mimarisi ve Mobil Desteğinin Kaldırılması:**
  - Tüm eski Android varlıkları, Gradle konfigürasyonları, izinleri ve derleme betikleri kaldırılarak tamamen özel bir Windows masaüstü uygulamasına geçiş yapıldı.
  - Kod tabanı, güçlü Windows kabuk desteği, derin bağlantılar (deep links) ve masaüstü odaklı iş akışlarına odaklanacak şekilde sadeleştirildi.

* **Güvenlik ve Token Şifreleme:**
  - Dart FFI aracılığıyla Windows DPAPI (`CryptProtectData` / `CryptUnprotectData`) kullanan ve kullanıcıya bağlı token ile kimlik bilgilerini güvenli bir şekilde şifreleyen `SecureStorageService` eklendi.

* **Protokol ve URI Şeması Entegrasyonu:**
  - Özel `discordstorage://` URI şemasını kaydetmek, komut satırı argümanlarını ayrıştırmak ve Discord mesaj kimliklerine sorunsuz bir şekilde derin bağlantı kurmak için `ProtocolService` uygulandı.

* **Masaüstü Bildirim Sistemi:**
  - Bildirim iletimi `local_notifier` paketine taşındı; yoğun dosya aktarımları sırasında ses spam'ini önlemek için ilerleme sınırlaması (throttling) ve akıllı ses engelleme özellikleri eklendi.

* **Akış Tabanlı Dosya Hashleme ve Performans:**
  - `FileHash` mekanizması, akış tabanlı hashlemeye (`openRead`) dönüştürülerek çok gigabaytlı dosyalar işlenirken Bellek Yetersizliği (OOM) hataları ortadan kaldırıldı ve bellek tüketimi önemli ölçüde düşürüldü.

* **Günlükleme ve Arayüz İyileştirmeleri:**
  - Canlı akış log çıkışı ve gelişmiş arama/filtreleme yetenekleriyle `LogsPage` arayüzü tamamen yenilendi.
  - Log dosyası depolama konumu `%APPDATA%\DiscordStorage\logs\` olarak değiştirildi ve Windows Gezgini'nde klasör açma işlevi düzeltildi.

* **Gizliliğe Saygılı Telemetri:**
  - Eski analiz sistemleri, gizliliğe saygılı ve şeffaf bir `TelemetryService` ile değiştirildi.

* **Derleme Betikleri ve CI/CD Paketleme:**
  - Kolay dağıtım için otomatik derleme (`build.ps1`, `build.bat`), dağıtım betikleri ve güncellenmiş InnoSetup (`InnoSetup.iss`) yükleyici yapılandırması eklendi.

* **Dokümantasyon ve Yerelleştirme:**
  - Kapsamlı teknik mimari dokümantasyonuyla `README.md` yenilendi ve eksiksiz Türkçe çeviri (`README.tr.md`) eklendi.

### 🐛 Hata Düzeltmeleri:

* **FileDownloader:** Doğru indirme ilerlemesi takibini sağlamak için bayt sayısı döndürme semantiği düzeltildi.
* **Arayüz ve Yerleşim:** Modern spesifikasyonlara uyum sağlamak için DragTarget güncellendi ve asenkron işlemler boyunca güvenli `mounted` bağlam kontrolleri zorunlu kılındı.
* **Bağlantı Oluşturucu:** Discord webhook bağlantı üretecindeki dize enterpolasyon (string interpolation) hataları giderildi.

### ⚠️ Kırıcı Değişiklikler (varsa):

* Android desteği tamamen sonlandırıldı; uygulama artık kesinlikle bir Windows Masaüstü istemcisidir.
* Windows DPAPI şifreli güvenli depolamaya geçiş nedeniyle daha önceden saklanan kimlik bilgilerinin yeniden tanımlanması gerekmektedir.