# Yerel mağaza paketi

Bu dosyalar taslaktır; hiçbir mağazaya yüklenmedi.

- `TR.md` / `EN.md`: ad, kısa açıklama, uzun açıklama, anahtar kelimeler ve ilk sürüm notları.
- `REVIEW_AND_PRIVACY.md`: veri beyanı ve incelemeci notları; hesap sahibinin son kontrolü bekliyor.
- `assets/play-icon.png`: 512 × 512 ikon.
- `assets/feature-graphic.png`: 1024 × 500 tanıtım grafiği.
- `screenshots/`: TR/EN Bugün, Plan ve Listeler ekranları; Android 1080 × 1920, iPhone 1320 × 2868 ve iPad 2064 × 2752. Gerçek Flutter ekranları örnek kayıtlarla widget ortamında render edildi; sistem çubukları ve native giriş ekranları içermez. iPad dikey görselleri ve yatay editör yerleşimi widget ortamında kontrol edildi. Son imzalı cihaz sürümüyle görsel karşılaştırma hâlâ gerekli.

Görselleri yeniden üretmek için:

```sh
swift tool/generate_brand.swift
flutter test test/reminder_ui_test.dart --dart-define=SHIEN_STORE_PREVIEWS=true --plain-name 'store previews'
```

Ekran çıktıları `build/previews/store` altındadır; gözden geçirdikten sonra bu klasöre kopyalanır. Tarih/saat üretildiği güne göre değişir. Örnek kayıtlar gerçek kullanıcı hesabına yazılmaz.

Kaynaklar: [Apple ekran boyutları](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [Play görsel kuralları](https://support.google.com/googleplay/android-developer/answer/9866151).
