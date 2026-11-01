# Yerel destek sayfaları

Bu klasör yayınlanmadı. Gizlilik, hesap silme ve destek sayfalarının TR/EN içeriğini içerir.

Yeniden üret: `python3 tool/build_release_site.py`

Yerelde önizleme: `python3 -m http.server 8765 --bind 127.0.0.1 --directory release_site`

Destek e-postası ve yasal mağaza sahibi bilgisi kullanıcıyla son kez doğrulandıktan sonra, ayrı bir yayın talimatıyla HTTPS barındırmaya alınabilir. Firebase Hosting yapılandırması yerelde hazırdır; otomatik dağıtım kurulmadı. Kullanıcı yayın onayı verdikten sonra yalnızca destek sayfaları `firebase deploy --only hosting --project shien-reminders` ile dağıtılabilir. Bu komut bu çalışma sırasında çalıştırılmadı. Web uygulaması değil, mağaza destek sayfalarıdır.
