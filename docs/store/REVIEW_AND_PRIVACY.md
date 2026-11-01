# Mağaza inceleme ve veri beyanı taslağı

31 Ekim 2026. Bu dosya konsollara gönderilmedi. Son imzalı sürümün SDK listesi ve mağaza sorularıyla birlikte gözden geçirilmeli.

## İşlenen veriler

| Veri | Nerede / neden | Hesapla ilişkili | İsteğe bağlı |
|---|---|---|---|
| E-posta, hesap kimliği | Firebase Authentication; giriş ve hesap yönetimi | Evet | Misafir kullanımında e-posta yok |
| Ad soyad | Kimlik sağlayıcı ve özel Firestore profili | Evet | Evet |
| Profil fotoğrafı | Sağlayıcının görseli veya özel Firestore profili | Evet | Evet |
| Hatırlatma başlığı, notlar, etiketler, zamanlar, geçmiş | Firestore; hesaba bağlı eşitleme | Evet | Misafir kayıtları yalnızca cihazda |
| Anonim kullanıcı kimliği | Firebase anonim oturumu | Anonim oturumla ilişkili | Çevrimdışı kullanım girişsiz mümkün |

Amaç: uygulama işlevi ve hesap yönetimi. Reklam, reklam kimliği ve kullanım analitiği entegrasyonu yok. Veri satışı veya reklam takibi yok. Firebase hizmet sağlayıcısı olarak kullanılır. Google/Apple giriş işlemleri ayrıca bu sağlayıcıların hizmet şartlarına tabidir.

Mağaza formlarında iletişim bilgileri, kullanıcı kimliği, fotoğraf ve diğer kullanıcı içeriği kategorilerini değerlendirin. Serbest notlara kullanıcı sağlık gibi hassas bilgiler yazabilir; sağlık kategorili kayıtların mağaza beyanlarına etkisi son formda ayrıca incelenmeli. Firebase SDK'larının teknik/güvenlik verileri için güncel sağlayıcı açıklamalarını kontrol edin. “Hiç veri toplanmıyor” seçilmemeli.

Aktarım Firebase üzerinden HTTPS/TLS kullanır. Uçtan uca şifreleme iddiasında bulunulmaz. Hesap silme içerikleri ve giriş hesabını kaldırır; eski cihazların içerikleri geri göndermesini önleyen minimal silinme işareti tutulur. Dışa aktarılmış dosyalar ve misafir kopyaları kullanıcı tarafından ayrıca silinir.

## İzin gerekçeleri

- Bildirim: kullanıcının kurduğu hatırlatmaları gösterir; izin reddi uygulamayı kullanmayı engellemez.
- Android kesin alarm erişimi: seçilen saate yakın yerel bildirim; erişim yoksa yaklaşık zamanlama.
- Fotoğraf: kullanıcının seçtiği profil görseli; sürekli galeri taraması yok.
- Kamera, konum, mikrofon ve kişi listesi kullanılmaz.

## İncelemeci notları (EN)

Shien is a personal reminder app. Guest mode works without an account. To review account sync, open Profile and sign in with the dedicated review email account that will be supplied in the store console. Do not use the developer's personal account.

Create a reminder with the + button. Today shows pending reminders; Plan shows upcoming dates; Lists groups reminders; Completed shows history. Notifications require OS permission. Background delivery depends on system settings. Reminders are local notifications, not remote push messages.

Account deletion is available in Profile > Delete account. It requires recent authentication. Apple users are asked to authenticate again so their Apple authorization can be revoked. Guest data remains local and is not automatically uploaded when signing in.

## Gönderimden önce doldurulacaklar

- Destek, gizlilik ve hesap silme sayfalarının gerçek HTTPS adresleri.
- Mağaza sahibi/yasal iletişim bilgileri ve hesap türü.
- Ayrı inceleme hesabının giriş bilgileri (yalnızca mağazanın özel alanına; depoya yazılmamalı).
- Yaş derecesi soruları: genel amaçlı kişisel araç; herkese açık kullanıcı paylaşımı/sohbet/reklam yok. Yaş derecesini konsolun yanıtlarına göre hesaplatın.
- Apple Export Compliance sorularını kullanılan standart şifrelemeye göre tamamlayın; değerlendirmeden Info.plist'e beyan eklenmedi.
- Desteklenen cihazlar: iPhone yanında iPad hedefi korunuyor; iPad ekran görüntüleri ve gerçek yerleşim kontrolü gönderimden önce tamamlanmalı.
