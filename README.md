# Trivia Arena

Parti bilgi yarışması ve harita fethi. Tek ekranda klavyeyle, telefonları kumanda yaparak ya da botlara karşı oynanır. 1200 çift dilli (TR/EN) soru, 12 kategori.

## Modlar

- **Trivia Arena**: Üç tur. Kategori halatı, kombo puanları, sabotajlı güç turu, son turda puanın cana dönüştüğü "son ayakta kalan".
  - **Hızlı düello**: Doğrudan son tur.
  - **Kombo maratonu**: 10 soru, sabotaj yok.
- **Bil ve Fethet**: Gerçek haritalarda üç perde. Önce kale kurulur, sonra tahmin sorularıyla toprak paylaşılır, en son düellolarla savaşılır. Düello soruları Trivia'nın bütün havuzundan rastgele gelir.

Oyunun içindeki **❓ Nasıl oynanır?** penceresi kuralları adım adım anlatır.

## Telefonla oynama

1. Bilgisayarda ya da TV'de siteyi aç, modu seç, **Ev partisi** veya **Online arena**'ya tıkla.
2. Ekranda 4 harfli kod ve QR çıkar. Telefonla QR'ı okut ya da siteyi açıp **Telefonum kumanda olsun**'a kodu yaz.
3. Sorular büyük ekranda görünür, cevaplar telefondan verilir. Maç bitince telefonda sıran ve ünvanın çıkar, oradan rövanş istenebilir.

Telefonlar sahneye sunucu (Socket.io) üzerinden bağlanır. Bu yüzden farklı ağlarda da (mobil veri, başka Wi-Fi) çalışır.

## Kalıcılık

| Ne | Nerede |
|---|---|
| Masa sıralaması (lig puanı), rekorlar, görülen sorular | Sahne cihazının tarayıcısında (`localStorage`) |
| Yarım kalan Trivia maçı | Sahne sekmesinde (`sessionStorage`). Sayfa yenilenirse maç o sorudan sürer. |
| Hesap, dünya sıralaması, oda sohbeti | Supabase (isteğe bağlı, giriş gerekir) |

Sahne sayfası yenilendiğinde oda kodu aynı kalır. Sunucu odayı 30 saniye bekletir, o sürede telefonlar kopmaz. Telefon sayfayı yenilerse aynı koltuğa kendiliğinden geri bağlanır.

> **Not:** Bil ve Fethet maçı henüz kurtarılamıyor. Maç sürerken sayfadan çıkmaya çalışınca tarayıcı uyarı verir.

## Çalıştırma

```bash
npm install
npm start          # http://localhost:3000
```

Node 18 veya üstü gerekir.

## Render'da yayınlama (ücretsiz)

1. Render'da **New → Web Service** ile bu repoyu bağla.
2. Build komutu: `npm install`, start komutu: `npm start`, instance: **Free**.
3. Yayın, `main` dalına her push'ta otomatik güncellenir.

### Sunucunun uyumasını engelle

Render'ın ücretsiz planı 15 dakika istek gelmezse sunucuyu uyutur. İlk açılış bu yüzden ~30 saniye sürer ve oyuncu siteyi bozuk sanabilir. Çözüm:

1. [UptimeRobot](https://uptimerobot.com) ya da [cron-job.org](https://cron-job.org)'da ücretsiz bir hesap aç.
2. `https://<senin-adresin>.onrender.com/healthz` adresini **5 dakikada bir** yoklayan bir izleyici (HTTP monitor) ekle.

Tek bir servis için bu, Render'ın aylık 750 saatlik ücretsiz kotasına sığar. `/healthz` şu an kaç sahnenin açık olduğunu da gösterir.

## Dosyalar

- `public/index.html`: Oyunun tamamı (arayüz, grafikler, sesler, soru bankası, oyun mantığı).
- `server.js`: Sayfayı sıkıştırarak sunar ve sahne ile telefonlar arasındaki mesajları aktarır. Oyun mantığı sunucuda değil.
