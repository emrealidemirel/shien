#!/usr/bin/env python3
"""Build local store support pages. Does not upload or deploy anything."""
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'release_site'
OUT.mkdir(exist_ok=True)
STYLE = '''body{font:17px/1.7 system-ui,sans-serif;background:#f6f7f9;color:#202735;margin:0}main{max-width:780px;margin:auto;padding:40px 24px 72px}a{color:#365c9c}nav{display:flex;gap:22px;flex-wrap:wrap;border-bottom:1px solid #dce1e9;padding-bottom:20px}h1{line-height:1.2}h2{margin-top:36px}p{white-space:pre-line}footer{margin-top:48px;color:#626f80}img{width:120px;height:120px;border-radius:24px}'''
NAV = '<nav aria-label="Navigation"><a href="index.html">Shien</a><a href="privacy.html">Gizlilik / Privacy</a><a href="delete-account.html">Hesap silme / Delete account</a></nav>'
def page(name, title, body):
    (OUT / name).write_text('<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><link rel="icon" type="image/png" href="icon.png"><title>'+html.escape(title)+' — Shien</title><style>'+STYLE+'</style></head><body><main>'+NAV+body+'<footer>Shien · Destek / Support: <a href="mailto:emrealidemirel@gmail.com">emrealidemirel@gmail.com</a></footer></main></body></html>\n')
def paragraphs(text):
    return ''.join('<p>'+html.escape(p)+'</p>' for p in text.split('\n\n') if p.strip())
import json
tr = json.loads((ROOT/'assets/translations/tr.json').read_text())['privacy_policy_body']
en = json.loads((ROOT/'assets/translations/en.json').read_text())['privacy_policy_body']
page('privacy.html', 'Gizlilik / Privacy', '<h1>Gizlilik politikası</h1>'+paragraphs(tr)+'<section lang="en"><h2>Privacy policy</h2>'+paragraphs(en)+'</section>')
source = (ROOT/'docs/ACCOUNT_DELETION.md').read_text()
tr = source.split('## Türkçe\n',1)[1].split('## English',1)[0].replace('**','')
en = source.split('## English\n',1)[1].replace('**','')
page('delete-account.html','Hesap silme / Delete account','<h1>Hesap silme</h1>'+paragraphs(tr)+'<section lang="en"><h2>Delete account</h2>'+paragraphs(en)+'</section>')
page('index.html','Destek / Support','<img src="icon.png" alt="Shien"><h1>Shien destek</h1><p>Hatırlatmalarını planla, gününü düzenle.</p><p>Yardım veya geri bildirim için aşağıdaki destek adresine yazabilirsin. Şifreni veya doğrulama kodlarını paylaşma.</p><section lang="en"><h2>Support</h2><p>Plan reminders and organize your day. Contact the support address below for help or feedback. Do not share passwords or verification codes.</p></section>')
(OUT/'icon.png').write_bytes((ROOT/'assets/app_icon/app_icon.png').read_bytes())
print('Built 3 local pages in release_site; nothing published.')
