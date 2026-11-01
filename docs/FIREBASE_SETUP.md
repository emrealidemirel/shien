# shien Firebase bağlantısı

30 Ekim 2026

## Ortam

- Proje: `shien-reminders` / `92765298655`.
- Android: `com.example.medicine_app`; iOS: `com.example.medicineApp`. Mevcut verileri korumak için kimlikler değiştirilmedi.
- Anonymous, Google ve Email/Password etkin.
- Android geliştirme SHA-1 kayıtlı; mağaza imzası henüz yok. iOS Google URL scheme ve client ID'leri yapılandırıldı.
- Cloud Firestore `(default)`: Frankfurt `europe-west3`, Standard, ücretsiz kota. `firestore.rules` ve `firestore.indexes.json` canlı projeye dağıtıldı.
- Storage, Analytics, Cloud Functions veya ücretli plan etkinleştirilmedi.
- En düşük sürümler: iOS 15, Android API 24; widget iOS 17.

## Paket uyumu

Firebase Core 4.x / Auth 6.x / Firestore 6.x ve Google Sign-In 7.x birlikte kullanılır. Kilit dosyası korunmalıdır. Firebase'in yeni ana sürümüne geçişte iOS GTMSessionFetcher ve Android Kotlin uyumu iki platformda yeniden doğrulanmalıdır.

## Veri ve senkronizasyon

- Misafir kayıtları Hive `reminders_v1` kutusunun `data` girdisinde kalır; buluta yazılmaz.
- Google/e-posta hesapları `account:<uid>` altında ayrı yerel kopya kullanır. Bulutta `users/<uid>/reminders`, `completions`, `profile/main` vardır. Bir hesabın verileri diğerinin ekranına veya bildirimlerine taşınmaz.
- Eski misafir kayıtları otomatik yüklenmez. Profildeki **Misafir kayıtlarını hesabıma aktar** eylemi onaydan sonra birleştirir; misafir kopyasını korur.
- Çevrimdışı değişiklikler kalıcı kuyruğa yazılır. Sunucunun aynı mutation ID'yi onaylaması kuyruğu temizler; eski onay yeni değişikliği silemez. Silinen kayıtlar içeriksiz silme kayıtlarıyla diğer cihazlara iletilir.
- Uygulama açıkken Firestore dinleyicileri değişiklikleri alır. Arka plan bildirim/widget eylemleri yerel kuyruğa alınır ve uygulama açıldığında işlenir. FCM veya uygulamayı kapalıyken uyandıran uzaktan senkronizasyon yoktur.
- Aynı kayıt iki cihazda değiştirilirse sunucuya son ulaşan değişiklik geçerli olur; alan bazında birleştirme yapılmaz. Aynı tekrarın iki cihazda tamamlanması aynı geçmiş kimliğini üretir.
- Profil adı Google/Firebase'den alınır; özel profil adı bunu geçersiz kılar. Sağlayıcı fotoğraf vermiyorsa baş harfler gösterilir. E-posta hesabında ad/fotoğraf profilden eklenir. Seçilen fotoğraf sıkıştırılır (en fazla 128 KiB), özel Firestore profil belgesinde saklanır; herkese açık fotoğraf deposu yoktur.
- Çıkış yerel hesap önbelleğini ve bulut hesabını silmez. Hesap silme yakın zamanda giriş gerektirir; önce tüm cihazların yazmasını engelleyen silinme işareti konur, ardından kayıtlar/profil ve Auth hesabı silinir. İçeriksiz UID/silinme işareti eski cihazların veriyi geri yüklemesini önlemek için kalır. Misafir kopyaları ve dışa aktarılmış dosyalar etkilenmez.

## Güvenlik ve doğrulama

- Firestore kuralları yalnızca aynı UID'ye sahip Google/e-posta oturumuna erişim verir. Misafir ve oturumsuz erişim reddedilir. Belge alanları ve boyutları sınırlandırılır.
- Canlı kurallar `python3 tool/verify_firestore_rules.py --live` ile denendi: sahip erişimi, ikinci oturum, başka hesap/anonim/oturumsuz erişim reddi, özel profil, silme kaydı ve silinen hesaba yazma engeli başarılı. Test kendi geçici hesaplarını ve belgelerini temizler; üretim kullanıcılarına dokunmaz.
- Çevrimdışı kuyruk, hesap ayrımı, eski sunucu onayı, bozuk kayıt, silme ve misafir aktarımı birim testleriyle kapsanır.
- Sağlayıcı profil fotoğrafı döndürmezse uygulama baş harfleri gösterir.
- Firebase istemci yapılandırmaları yönetici sırrı değildir. CLI tokenları, servis hesabı anahtarları ve test şifreleri depoya yazılmaz.

## Yayın için kalanlar

### API anahtarı kontrolü

1 Kasım 2026'da Google Cloud konsolunda Android, iOS ve tarayıcı anahtarları incelendi. Üçünde de 25 API içeren izin listesi bulunuyor. Doğrudan Generative Language (Gemini) ve Vertex AI API'leri listede yok; Firebase AI Logic listede mevcut. İzin listesinde bulunmak, ilgili servisin projede etkin olduğu anlamına gelmez.

Uygulama kısıtlamaları üç anahtarda da `None`. Kalıcı paket kimlikleri ve yayın imzaları tamamlandığında platform kısıtlamaları ve yalnızca kullanılan servislere yönelik daha dar API listesi test edilmelidir. Bu kontrolde canlı ayarlar değiştirilmedi. Firebase istemci anahtarları yönetici erişimi sağlamaz; veri güvenliği Firestore kuralları ve kimlik doğrulamaya dayanır.

Referans: https://firebase.google.com/docs/projects/api-keys

Üretim Android imzası/Play SHA değerleri, Apple dağıtım sertifikaları ve Apple giriş yapılandırması, kalıcı mağaza kimlikleri, herkese açık gizlilik/hesap silme sayfaları ve fiziksel cihaz testleri için `RELEASE_PLAN.md` dosyasına bakın.
