# Teknik doğrulama

Son yerel kontrol: 1 Kasım 2026.

| Kontrol | Sonuç |
| --- | --- |
| Flutter statik analiz | Bulgu yok |
| Birim ve widget testleri | 101 test başarılı |
| Dart biçim kontrolü | 54 dosya, değişiklik yok |
| Git diff biçim kontrolü | Temiz |
| Android release derlemesi | Başarılı; imzasız AAB |
| iOS simülatör derlemesi | Başarılı |

Testler; dil geçişi, hesap ayrımı, çevrimdışı kuyruk, tekrar hesapları, bildirim kapasitesi, yedekleme ve tablet yerleşimi senaryolarını kapsar. Otomatik testler fiziksel cihaz bildirim teslimini veya mağaza kabulünü garanti etmez.

Uygulama henüz mağaza yayınına hazır değildir. Sağlayıcı ve kimlik geçişi, imzalama, fiziksel cihaz kabulü ve mağaza bilgileri için [yayın kontrol listesi](RELEASE_PLAN.md) izlenmelidir.

Özel anahtarlar, servis hesabı dosyaları, imzalama dosyaları ve yerel ortam dosyaları kaynak kontrolünün dışında tutulur. Firebase istemci yapılandırmaları yönetici kimlik bilgileri değildir; veri erişimi sunucu tarafındaki kurallarla korunur.
