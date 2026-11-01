# Apple ile giriş — yerel kod hazır, sağlayıcı ayarı bekliyor

1 Kasım 2026. Apple App ID ve widget grubu kaydedildi; Firebase sağlayıcı ayarı henüz değiştirilmedi.

## Doğrulanan Apple kayıtları

- Team ID: `4JH4MFPQDA`
- Ana uygulama: `com.emrealidemirel.shien` (Sign in with Apple ve App Groups etkin)
- Widget: `com.emrealidemirel.shien.ReminderWidget` (App Groups etkin)
- Ortak grup: `group.com.emrealidemirel.shien.reminders` (iki App ID'ye atandı)

Yerel paket kimlikleri henüz değiştirilmedi; Firebase/OAuth yapılandırmasıyla birlikte taşınacak. Provisioning ve gerçek cihaz doğrulaması tamamlanmadı.

## Hazırlanan

- Firebase SDK üzerinden `AppleAuthProvider`, ad/e-posta kapsamları, misafir oturumunu bağlama ve mevcut hesaba giriş.
- iOS profil ekranında Apple seçeneği. Varsayılan kapalı; yapılandırma tamamlanınca `--dart-define=SHIEN_APPLE_SIGN_IN=true` ile açılır. Android'de gösterilmez.
- Hesap silmeden önce Apple ile yeniden kimlik doğrulama; taze yetkilendirme koduyla token iptali. İptal edilen veya kod döndürmeyen giriş bulut kayıtlarını silmez.
- Runner entitlement içinde Sign in with Apple capability.
- Yerel Firestore kurallarına `apple.com` eklendi. Henüz dağıtılmadı; canlı kurallar yalnızca Google/e-posta sağlayıcılarına izin vermeye devam eder.

## Kalan yapılandırma

1. Yeni bundle ID için Firebase uygulaması ve Google OAuth kaydı hazırlanır. Mevcut yerel kimlik `com.example.medicineApp`; geçiş tamamlanmadan değiştirilmemeli. Simülatördeki eski uygulama/verileri silinmemeli.
2. Yeni kimlikler Xcode, widget ve ortak grup kaynaklarına birlikte işlenir. Uygun provisioning profili oluşturulur.
3. Firebase Apple sağlayıcısı etkinleştirilir. Gerekli Team ID, Key ID ve özel anahtar Developer hesabından alınır; özel anahtar depoya yazılmaz. Apple e-posta gizleme kullanılıyorsa Firebase doğrulama e-postaları için relay alanları yapılandırılır.
4. Apple sağlayıcı kuralları gözden geçirilip Firestore'a dağıtılır. Kurallar henüz dağıtılmadı.
5. Gerçek cihazda yeni hesap, tekrar giriş, e-posta gizleme, iptal, misafirden geçiş, senkronizasyon ve hesap silme denenir. İkinci girişte Apple'ın ad döndürmemesi durumunda kalıcı ad korunmalı.
6. Doğrulama sonrası yayın derlemesine `SHIEN_APPLE_SIGN_IN=true` eklenir. Bayrak kapalı iOS sürümü mevcut Google giriş akışıyla mağazaya gönderilmemeli.

Referans: https://firebase.google.com/docs/auth/flutter/federated-auth
