# Steam'e çıkış rehberi

Oyun Steam'e hazır yazıldı: `scripts/core/steam_service.gd` GodotSteam kuruluysa
Steam'i kullanır, değilse oyun aynen çalışır (başarımlar profilde tutulur, oyun
içinde bildirim çıkar). Aşağıdaki adımlar sırayla yapılır.

## 1. Steamworks hesabı ve App ID

1. <https://partner.steamgames.com> üzerinden Steamworks'e katıl, uygulama ücretini öde.
2. Yeni bir uygulama aç; sana bir **App ID** verilir.
3. `game/steam_appid.txt` içindeki `480`'i (Valve'ın test oyunu Spacewar) kendi App ID'nle değiştir.
   Aynı sayıyı `steam_service.gd` içindeki `APP_ID`'ye de yaz.

## 2. GodotSteam'i kur

İki yol var:

- **Godot içinden:** AssetLib → "GodotSteam GDExtension" ara → indir → `addons/godotsteam` olarak kur.
- **Betikle:** `bash game/tools/steam/install_godotsteam.sh` (sürüm adını
  <https://github.com/GodotSteam/GodotSteam/releases> sayfasından kontrol et).

Godot'yu yeniden aç. Steam açıkken oyunu çalıştırınca çıktıda
`[Steam] steamInitEx: Steamworks active` görmelisin.

## 3. Başarımlar ve istatistikler

`tools/steam/achievements.json` içindeki 12 başarımı ve 2 istatistiği (`matches`, `wins`)
Steamworks → *Stats & Achievements* sayfasında **aynı id'lerle** tanımla. Her başarım
için 256×256 iki simge (açık ve gri) gerekir. Tanımlar bitince **Publish** de.

## 4. Zengin durum (arkadaş listesi)

Steamworks → *Community* → *Rich Presence* sayfasına `tools/steam/rich_presence.vdf`
dosyasını yükle. Arkadaşların seni "Anadolu'yu fethediyor" diye görür.

## 5. Çevrimiçi: Remote Play Together

Steamworks → *Application* → *Remote Play* → **Remote Play Together**'ı aç. Oyun zaten
çok girişli (2 klavye + gamepad'ler + telefonlar), ek ağ kodu gerekmez: menüdeki
**Çevrimiçi → Arkadaş davet et** Steam'in davet penceresini açar, gelen arkadaşın
gamepad'i sahnede yeni bir pelüş olur. Arkadaşın oyunu satın almak zorunda değil.

Ayrıca **Arkadaş lobisi aç** bir Steam lobisi kurar; arkadaşın profilinden "Oyuna
katıl" deyince istek oyuna gelir (`SteamService._on_join_requested`). Gerçek (yayınsız)
ağ oyunu için sonraki adım: Steam lobisinin üstüne `SteamMultiplayerPeer` ile
girdi aktarımı. Mimari hazır: telefon kumandası da aynı yolu kullanıyor
(`Controllers.Phone` girişi uzaktan gelir, sahne ana makinede döner).

## 6. Dışa aktarma ve yükleme

1. Godot → Proje → Dışa Aktar: `game/export_presets.cfg` içinde Windows ve Linux hazır.
   Dışa aktarma şablonlarını bir kez indir.
2. Çıktılar `build/windows` ve `build/linux` klasörlerine gider. GodotSteam'in
   `steam_api64.dll` / `libsteam_api.so` dosyalarının çıktının yanına kopyalandığını kontrol et.
3. SteamPipe (`steamcmd` + `app_build.vdf`) ile iki depoyu yükle, *Builds* sayfasında
   `default` dalına ata.

## 7. Mağaza sayfası kontrol listesi

- Kapsül görseller: 460×215 (başlık), 231×87 (küçük), 616×353 (ana), 374×448 (dikey), 3840×1240 (kütüphane arka planı)
- En az 5 ekran görüntüsü (docs/screenshots iyi bir başlangıç), 1 fragman
- Kısa açıklama (TR/EN), etiketler: Party, Trivia, Local Multiplayer, Remote Play Together, Casual
- Yaş derecelendirmesi (IARC anketi)
- Steam Deck: gamepad ile bütün menüler gezilebiliyor; metin boyutu 1280×800'de okunaklı
- "Coming Soon" sayfası çıkıştan en az 2 hafta önce yayında olmalı
