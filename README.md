# Trivia Arena — Bedava Oynanabilir Sürüm

Bu, oda kodlu, çok oyunculu, telefondan oynanabilen çalışan bir trivia oyunu.
Aşağıdaki adımları takip ederek TAMAMEN BEDAVA yayına alabilirsin.
Kod bilmene gerek yok — sadece kopyala/yapıştır ve tıkla.

## Adım 1 — GitHub hesabı aç (2 dk)
1. https://github.com adresine git, "Sign up" ile ücretsiz hesap oluştur.

## Adım 2 — Bu projeyi GitHub'a yükle
1. GitHub'da sağ üstten "+" > "New repository" tıkla.
2. İsim ver (örnek: `trivia-arena`), "Create repository" de.
3. Açılan sayfada "uploading an existing file" linkine tıkla.
4. Sana verdiğim ZIP dosyasını AÇ (extract et), içindeki tüm dosya ve
   klasörleri (server.js, package.json, public/ klasörü, README.md)
   sürükleyip bu sayfaya bırak.
5. Altta "Commit changes" butonuna bas.

## Adım 3 — Render.com'da bedava host et
1. https://render.com adresine git, GitHub hesabınla ücretsiz kaydol.
2. Dashboard'da "New +" > "Web Service" seç.
3. Az önce yüklediğin `trivia-arena` reposunu seç ve bağla.
4. Ayarlar ekranında:
   - **Name:** istediğin bir isim (örn. `trivia-arena`)
   - **Region:** sana yakın bir bölge
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** **Free** seç
5. "Create Web Service" butonuna bas.
6. 2-3 dakika bekle, build tamamlanınca sana bir link verecek:
   `https://trivia-arena-xxxx.onrender.com` gibi.

## Adım 4 — Oyna!
1. O linki telefonundan/bilgisayarından aç.
2. Adını yaz, "Oda Kur" de.
3. Sana 4 haneli bir oda kodu verilecek.
4. Arkadaşların aynı linke girip o kodu yazarak katılsın.
5. Host olarak "Oyunu Başlat" de — herkes aynı anda soruları görecek.

## Not: Ücretsiz plan sınırlaması
Render'ın bedava planında sunucu 15 dakika kullanılmazsa uykuya geçer ve
tekrar açılması ~30 saniye sürer. Oyun sırasında sorun olmaz, sadece ilk
açılışta biraz bekleme olabilir.

## Soruları değiştirmek istersen
`server.js` dosyasını aç, en üstteki `QUESTIONS` listesini düzenle.
Her soruya `prompt` (soru metni), `options` (4 şık) ve `correctIndex`
(doğru şıkkın index'i, 0'dan başlar) ekle. Değişikliği kaydedip GitHub'a
tekrar yükle (Adım 2'deki gibi) — Render otomatik olarak yeniden
yayınlayacak.

## Şu an neler çalışıyor
- Oda kurma / oda koduyla katılma
- 4 soruluk round, 12 saniyelik zamanlayıcı
- Hız bazlı puanlama (ne kadar hızlı doğru cevaplarsan o kadar puan)
- Canlı skor tablosu ve final sıralaması
- Bağlantı kopması durumunda host otomatik devrediliyor

## Sonraki geliştirmeler (istersen ben yazarım)
- Round 2 (Soygun & Sabotaj), Round 3 (Bahis), Round 4 (Sudden Death)
- Kendi soru paketini yükleme ekranı
- Avatar seçimi
