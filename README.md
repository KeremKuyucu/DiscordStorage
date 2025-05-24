Aşağıda, verdiğin `README.md` dosyasını daha okunabilir, profesyonel ve açık hale getirdim. Dil bilgisi ve yapı açısından bazı düzenlemeler yaptım, ayrıca başlıkları daha akıcı hale getirerek bazı yerleri sadeleştirdim:

---

# DiscordStorage

<div align="center">
  <img src="assets/logo.png" alt="DiscordStorage Logo" width="200">
  <p>📦 Discord üzerinden dosya depolama ve paylaşım uygulaması</p>
</div>

## 📑 İçindekiler

* [Proje Hakkında](#-proje-hakkında)
* [Özellikler](#-özellikler)
* [Kurulum](#-kurulum)
* [Kullanım](#-kullanım)
* [Teknik Detaylar](#-teknik-detaylar)
* [Uyarılar](#-uyarılar)
* [Sürüm Geçmişi](#-sürüm-geçmişi)
* [Katkıda Bulunma](#-katkıda-bulunma)
* [Lisans](#-lisans)

---

## 🔍 Proje Hakkında

**DiscordStorage**, dosyalarınızı Discord sunucuları aracılığıyla güvenli ve pratik bir şekilde saklamanızı sağlayan çapraz platform bir uygulamadır. **Flutter** ile geliştirilmiştir ve **Android** ile **Windows** platformlarını destekler.

Bu proje, daha önce C++ ile geliştirilen [DiscordStorageCpp](https://github.com/keremkuyucu/discordstorageCpp) projesinin geliştirilmiş ve modernleştirilmiş Flutter sürümüdür.

---

## 🚀 Özellikler

* 📁 Discord sunucularında dosya saklama ve yönetme
* 🔐 Bot token’ı yalnızca yerel cihazda saklanır
* 📤 Büyük dosyaları otomatik olarak 8MB’lık parçalara ayırarak yükleme
* 📥 Parçaları otomatik olarak birleştirerek indirme
* 🧪 Gelişmiş hata takibi için `debugLog` desteği
* 🧾 SHA-256 hash algoritması ile dosya bütünlüğü kontrolü
* 🖥️ Mobil ve masaüstü uyumlu sade ve modern kullanıcı arayüzü
* 🔄 Otomatik güncelleme kontrol sistemi

---

## 💻 Kurulum

### Windows

1. [Releases](https://github.com/KeremKuyucu/DiscordStorage/releases) sayfasından en son sürümü indir.
2. Kurulum dosyasını çalıştır ve yönergeleri takip et.
3. Kurulum tamamlandığında uygulamayı başlat.

### Android

1. [Releases](https://github.com/KeremKuyucu/DiscordStorage/releases) sayfasından en son `.apk` dosyasını indir.
2. APK dosyasını cihaza yükle ve gerekli izinleri ver.
3. Uygulamayı başlat.

### Geliştiriciler için

```bash
# Depoyu klonla
git clone https://github.com/KeremKuyucu/DiscordStorageNew.git

# Bağımlılıkları yükle
flutter pub get

# Uygulamayı başlat
flutter run
```

---

## 📱 Kullanım

### Başlangıç Ayarları

1. [Discord Developer Portal](https://discord.com/developers/applications)'dan bir bot oluştur ve token’ı al.
2. Uygulamada **Ayarlar** sekmesine gir.
3. Bot token’ını gir ve "Token Kontrol Et" butonuna tıkla.
4. Sunucu ID ve Kategori ID bilgilerini gir.
5. "Kaydet" butonuna tıklayarak ayarları tamamla.

### Dosya Yükleme

1. Ana ekranda **"Dosya Yükle"** butonuna tıkla.
2. Yüklemek istediğin dosyayı seç.
3. Yükleme işlemi otomatik olarak başlar ve tamamlandığında ana ekranda listelenir.

### Dosya İndirme

1. Ana ekranda indirmek istediğin dosyayı seç.
2. **"İndir"** butonuna tıkla.
3. Dosya otomatik olarak indirilir ve cihazının **İndirilenler** klasörüne kaydedilir.

---

## 🔧 Teknik Detaylar

### Parçalama ve Birleştirme

* Discord’un 8MB yükleme limiti nedeniyle, dosyalar bu boyuta göre parçalara ayrılır.
* Her parça için bir JSON kaydı tutulur.
* İndirme sırasında tüm parçalar sırayla birleştirilir.

### Dosya Bütünlüğü

* Yükleme ve indirme işlemlerinde **SHA-256** hash algoritması ile bütünlük doğrulaması yapılır.


## ⚠️ Uyarılar

* Bir dosya yüklendikten sonra **ilgili Discord kanalına manuel mesaj göndermeyin**. Aksi halde sistem bozulabilir.
* Botun yetkilerinin eksiksiz olduğundan emin olun.
* İsterseniz botun özel kategorisinde tam yetki verip sunucuda yetkisiz bırakabilirsiniz.
* Büyük dosyalar için cihazınızda yeterli boş alan bulunduğundan emin olun.

---

## 🤝 Katkıda Bulunma

Katkı sağlamak için:

1. Depoyu forklayın
2. Yeni bir dal oluşturun: `git checkout -b yeni-ozellik`
3. Değişiklikleri commit edin: `git commit -m "Yeni özellik eklendi"`
4. Dalı pushlayın: `git push origin yeni-ozellik`
5. Bir Pull Request gönderin

---

## 📄 Lisans

Bu proje [LICENSE](LICENSE) dosyasında belirtilen açık kaynak lisansı kapsamında dağıtılmaktadır.

---

<div align="center">
  <p>Geliştirici: <strong>Kerem Kuyucu</strong></p>
  <p>© 2023-2024 DiscordStorage</p>
</div>

---

