# Trivia Arena: The Grand Stage

![Lobi: Büyük Sahne](docs/screenshots/lobby.jpg)

Fizik motoruyla çalışan, kaotik bir 3D parti bilgi yarışması. Kırmızı kadife perdelerin, pirinç tabelaların ve dev spot ışıklarının altında küçük pelüş karakterler koşar, zıplar, birbirine omuz atar. Soruyu bilmek yetmez: doğru kapağın üstünde durman da gerekir.

- **Motor:** Godot 4.7 (Forward+, Jolt fizik)
- **Web prototipi:** `web-archive` dalında (`v1.0-web`). Bu dala dokunulmaz.
- **Tasarım belgesi:** [docs/DESIGN.md](docs/DESIGN.md)

| | |
|---|---|
| ![Perde açılışı](docs/screenshots/act_card.jpg) | ![Kategori halatı](docs/screenshots/tug.jpg) |
| **Perde kartı:** kadife perde iner, tur adı harf harf düşer | **Kategori halatı:** dairene gir, zıpla, çek |
| ![Soru](docs/screenshots/question.jpg) | ![Cevap](docs/screenshots/reveal.jpg) |
| **Soru:** süre bitince üstünde durduğun kapak cevabındır | **Cevap:** seri alevi, dönen puanlar |
| ![Ödül](docs/screenshots/reward.jpg) | ![Can turu](docs/screenshots/final.jpg) |
| **Güç turu:** en hızlı doğru 400 puan çalar ya da sabote eder | **Can turu:** yalnız en hızlı doğru kurtulur |
| ![Final](docs/screenshots/result.jpg) | ![Conquest Quiz](docs/screenshots/conquest.jpg) |
| **Final:** konfeti, karne, rövanş | **Conquest Quiz:** doğru kürsüye ilk basan karoyu boyar |
| ![Kostüm odası](docs/screenshots/wardrobe.jpg) | ![Ev partisi](docs/screenshots/house.jpg) |
| **Kostüm odası:** şapka, bıyık, papyon, kumaş | **Ev partisi:** QR'ı okut, telefonun kumanda olsun |

## Çalıştırma

1. [Godot 4.7](https://godotengine.org/download) indir. Standart sürüm yeterli, .NET gerekmez.
2. Godot'da **İçe aktar** → `game/project.godot` → **Çalıştır** (F5).

Komut satırından: `godot --path game`

## Kontroller

| Oyuncu | Koş | Zıpla | Omuz at |
|---|---|---|---|
| 1. klavye | WASD | Boşluk | F |
| 2. klavye | Oklar | Enter | Sağ Shift |
| Gamepad | Sol çubuk / d-pad | A | X ya da B |
| Telefon (Ev partisi) | Ekrandaki joystick | ZIPLA | OMUZ |

Lobide katılmak için kendi tuşuna basman yeterli. Menüler fareyle ya da klavye/gamepad odağıyla kullanılır.

## Modlar

### Trivia Arena: üç perdelik klasik şov

Kurallar web sürümündeki klasik partiyle aynıdır; bütün sayılar `game/data/rules.tres` dosyasındadır.

1. **Kategori halatı.** Her perde, sahneye inen üç kategori dairesiyle açılır. İstediğin kategorinin dairesine gir ve zıpla: her zıplayış bir çekiştir. Rakibini daireden itmek serbest. En çok çekilen kategori, o perdenin bütün sorularını belirler.
2. **Perde I · Kategori avı.** 4 soru (kolay, kolay, orta, zor). Süre bitince hangi kapağın (A-B-C-D) üstündeysen cevabın odur. Doğrular 250 · 250 · 500 · 750 diye tırmanır; yanlış seriyi sıfırlar.
3. **Perde II · Güç turu.** 4 soru. Her sorunun en hızlı doğru bileni seçer: bir rakipten 400 puan çal ya da ona bir soruluk sabotaj yap (kurşun ayakkabı, ters kumanda, buz pisti, dev kafa).
4. **Perde III · Son ayakta kalan.** Puanın cana döner (en az liderin %35'i, en az 1000). Her soruda yalnız en hızlı doğru kurtulur; diğer herkes bedel öder. Bedel her soruda büyür ve masa küçüldükçe sertleşir. Canı biten, kendi kapağından sahnenin altına düşer. Son kalan kazanır.

Yanlış cevap seni hemen oyundan atmaz; kaybettikçe can kaybedersin.

### Conquest Quiz

28 karolu sahnede her soru bir hedef karoyu parlatır. Doğru kürsüye ilk basan onu kendi rengine boyar; yanlış kürsü çarpar. Kendi renginde hızlanır, rakibin boyasında yavaşlarsın. 12 sorunun sonunda en çok karo kazanır.

### Diğerleri

- **Karakterim:** sahnenin ortasında, tek spotun altında kostüm seçimi.
- **İzleyici:** yan duvardaki locadan izle; sahneye gül, domates ya da şapka fırlat.
- **Ev partisi:** evde tek ekran, diğer oyuncular telefonlarını kumanda olarak kullanır.

## Neyi nereden düzenlerim?

Godot'da `game/project.godot`'u aç. En sık dokunulacak yerler:

| Ne değişecek | Nereden |
|---|---|
| Süreler, puanlar, bedel formülü, sabotaj gücü | `data/rules.tres` → Inspector. Kod gerekmez. |
| Sahne düzeni (sahne, dekor, kamera, arayüz düğümleri) | `scenes/main.tscn`. Sahne, dekorlar ve kamera editörde canlı görünür. |
| Arayüz renkleri | `scripts/ui/pal.gd` (en üstteki sabitler) |
| Yazı tipleri (kalınlık, harf aralığı) | `ui/fonts/*.tres` → Inspector: `variation_opentype` (wght, opsz), `spacing_glyph` |
| Tema (metin kutuları, varsayılan yazı) | `ui/theme/grand_stage.tres` |
| Işık/parıltı efektleri | `ui/shaders/*.gdshader` (her dosyanın başında ne yaptığı yazar) |
| Arayüz parçalarını denemek | `scenes/ui_gallery.tscn`: logo, düğmeler, seçiciler; Inspector'dan metin/renk değiştir |
| Metinler (TR/EN) | `scripts/core/i18n.gd` |
| Sorular | `data/questions.json` (1200 çift dilli soru) |
| Kostümler | `scripts/actors/plush_visual.gd` (`HATS`, `MUSTACHES`, `BOWTIES`, `COLORS`) |
| Bot zekâsı | `scripts/modes/classic_show.gd` (`BOT_ACC`, `BOT_READ`) |

Denemek için kısayollar (komut satırı, `--` sonrasına):

```bash
godot --path game -- --round=3            # Trivia'yı doğrudan can turundan başlat
godot --path game -- --ff=2               # bekleme sürelerini yarıya indir
godot --path game -- --timescale=2        # bütün oyunu hızlandır
```

## Ev partisi sunucusu (telefon kumandası)

Telefonlar oyuna küçük bir Node sunucusu üzerinden bağlanır (`server/`).

```bash
cd server
npm install
npm start            # http://localhost:3000  (kumanda: /pad, QR: /qr.png, WS: /ws)
```

Oyunda **Ev partisi**'ne tıkla. Açılan kartta sunucu adresini gir (yerelde `ws://localhost:3000/ws`, yayında `wss://<adres>/ws`) ve **Bağlan**'a bas. Kartta QR ve 4 harfli kod çıkar.

Evdeki telefonların PC'ye erişebilmesi için yerel ağ adresini kullan (ör. `ws://192.168.1.20:3000/ws`) ya da sunucuyu yayına al:

**Render'da yayın (ücretsiz):** Yeni bir *Web Service* aç ve bu repoyu bağla.

| Ayar | Değer |
|---|---|
| Root Directory | `server` |
| Build Command | `npm install` |
| Start Command | `npm start` |

Uyumasın diye `https://<adres>/healthz` adresini 5 dakikada bir yoklayan bir izleyici kur (UptimeRobot, cron-job.org).

> Web prototipini yayındaki Render servisinde tutmak için o servisin dalını `web-archive` yap.

## Testler

```bash
godot --headless --path game --import                  # ilk seferde
godot --headless --path game res://tests/tests.tscn    # çıkış kodu = kalan test sayısı
godot --headless --path game -s res://tools/check_scripts.gd   # bütün betikleri derle
```

Testlerin kapsamı:

- Sözlük, soru bankası ve profil karnesi.
- Kurallar: kombo merdiveni, tur 3 bedel formülü, zorluk sırası.
- Pelüş fiziği: koşma, zıplama, omuz yiyip devrilme ve kalkma, düşünce elenme.
- Sahne kurulumu ve kapaktan düşme.
- Botlarla baştan sona tam bir klasik şov (halat, soygun/sabotaj, can turu, ölüm) ve tam bir Conquest maçı.

Telefon kumandasının uçtan uca testi: sunucuyu çalıştır, sonra `godot --headless --path game res://tests/phone_host.tscn -- --relay=ws://localhost:3000/ws`.

Ekran görüntüsü aracı:

```bash
godot --path game -- --shot=lobby,setup,arena_intro,arena_tug,arena_q,arena_open,result --shotdir=/tmp/shots --timescale=2
```

## Klasörler

```
game/
  scenes/main.tscn        oyunun sahne ağacı (Stage, Props, Actors, Camera, UI)
  scenes/ui_gallery.tscn  arayüz parçaları vitrini
  data/rules.tres         bütün oyun sayıları
  data/questions.json     1200 çift dilli soru (+ 34 tahmin sorusu)
  ui/fonts/               yazı tipi ayarları (Big Shoulders, Fraunces)
  ui/theme/               Godot teması
  ui/shaders/             parıltı, ampul, halka sayaç, kadife perde, gren, spot
  scripts/core/           dil (TR/EN), profil ve karne, soru bankası, kurallar, kodla üretilen sesler
  scripts/stage/          sahne, perdeler, ışık, kapaklar, dekorlar
  scripts/actors/         pelüş fizik + görünüş, kontrolcüler (klavye, gamepad, telefon, bot)
  scripts/camera/         balkon kamerası
  scripts/modes/          Trivia Arena (classic_show.gd), Conquest Quiz
  scripts/ui/             arayüz: pal.gd (renk/yazı), fx.gd (hareket), icons.gd (simgeler)
    components/           logo, menü satırı, düğmeler, seçiciler, profil kartı, 3D portre
    screens/              lobi menüsü, kostüm odası, ev partisi, loca, afiş
    hud/                  skor şeridi, soru kartı, sayaç, halat, perde kartı, ödül, final
  scripts/net/            telefon köprüsü
  tests/                  başsız testler
  tools/                  betik derleme denetimi
server/                   telefon kumandası sunucusu (Node, ws)
docs/                     tasarım belgesi, ekran görüntüleri
```

## Lisanslar

Yazı tipleri SIL Open Font License altındadır (`game/assets/fonts/OFL-*.txt`): Big Shoulders, Fraunces. Bütün modeller, dokular ve sesler çalışma anında kodla üretilir.
