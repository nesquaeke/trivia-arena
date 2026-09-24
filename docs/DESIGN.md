# Trivia Arena: The Grand Stage — Tasarım Belgesi

Web prototipi (`web-archive` dalı, `v1.0-web`) bir kavram kanıtıydı. Bu belge, oyunu fizik motoruyla beslenen kaotik bir 3D parti oyununa taşıyan tasarımın ve şu anki uygulamanın haritasıdır.

---

## 1. Atmosfer ve sahne kimliği: "The Grand Stage"

Lobi bir bekleme odası değil. Oyunun tonunu belirleyen, yaşayan bir tiyatro sahnesi.

| Tasarım maddesi | Uygulama (v0.1) | Dosya |
|---|---|---|
| Koyu bordo kadife halı | Hücresel gürültü normal haritası + kadife parıltısı (rim) | `stage/stage.gd` → `m_carpet()` |
| Kat kat ağır tiyatro perdeleri | Kodla üretilen kıvrımlı kumaş ağı: arka fon (2 kat), kulis kanatları (3×2), fistolu üst saçak, bağlı yan dökümler | `Stage.curtain_mesh()` |
| Önde açılıp kapanan ana perde | İki yarım, sahne geçişlerinde kapanır/açılır | `Stage.set_curtain()` |
| Loş, hacimsel ışık ve toz | Forward+ hacimsel sis, sisle etkileşen spotlar, 700 toz zerresi | `_build_environment`, `_build_lights`, `_build_dust` |
| Yaldızlı sahne ağzı | Lake sütunlar, yivli altın çubuklar, arma | `_build_proscenium` |
| Dev soru panosu | Ampullü çerçeveli pano; içerik bir SubViewport'a çizilen arayüz | `ui/board_screen.gd` |
| Ön ışık oluğu, seyirci koltukları, loca | Pirinç kapaklı ampuller (sırayla yanar), 110 koltuk, yan duvarda yaldızlı loca | `_build_floor`, `_build_audience`, `_build_balcony_box` |

### Etkileşimli dekorlar
Hepsi fizikli (`RigidBody3D`, `prop` grubu). Karakterler çarpınca devrilir, omuz atınca savrulur.

- Vintage ayaklı mikrofonlar (düşük ağırlık merkezi, yuvarlanır)
- Karton sütunlar (hafif, kolay devrilir)
- Dev karton soru işareti, komedi/trajedi maskeleri, sandıklar
- Jüri masası: sabit, üstüne zıplanabilir. Devrilen sandalyeleri ve çarpınca çalan pirinç zili var.

### Fizik ve karakter kaosu (Party Panic ekolü)
`actors/plush.gd`: `RigidBody3D` üzerine kurulu kuvvet tabanlı hareket.

- **Ayakta:** Dönme kilitli, ivmeli koşu (5,4 m/s), zıplama (~1,3 m), çakal zamanı ve zıplama tamponu var.
- **Omuz atma:** Önündeki koniye itme + küçük atılma. Denge azalır; denge biterse ya da %35 ihtimalle hedef devrilir.
- **Hızlı çarpışma:** 3,8 m/s üstü yaklaşma hızında karşıdaki sendeler ya da devrilir.
- **Devrilme ("ragdoll hissi"):** Kilitler açılır, gövde gerçekten yuvarlanır, kollar-bacaklar çırpınır. 1–1,6 sn sonra doğrulup kalkar (görünüş yumuşakça dikleşir).
- **Görünüş** (`actors/plush_visual.gd`): Keçe dokulu sarı pelüş, düğme gözler, dikişli gülüş, karın yaması, ayı kulakları. Yürüyüş salınımı, iniş sıkışması (yay), ivmeye gecikmeli kafa yayı ve göz kırpma var.

> Tam iskeletli ragdoll (PhysicalBone3D) v0.3 hedefidir. Şimdiki çözüm tek gövdenin gerçekten devrilmesi + prosedürel uzuv çırpınması. Oynanışta aynı komik hissi veriyor ve ağ senkronizasyonu çok daha ucuz.

---

## 2. Arayüz: "Anti-AI Slop", dokulu ve diegetik

Yuvarlak neon düğme yok. Pirinç levhalar, koyu ahşap, kadife ve kağıt var; hepsi kodla çizilir (`ui/ui_kit.gd`).

- **Sol pano (%24):** Yarı saydam ahşap, pirinç çerçeve, köşe gönyeleri. Sahne arkada görünmeye devam eder.
  - Ampullü tabela: kovalayan ampuller, titrek neon başlık (Limelight).
  - Mod plaketleri: Trivia Arena, Conquest Quiz, Ev partisi, Karakterim, İzleyici, Nasıl oynanır. Kazınmış yazı ve köşe vidaları var.
- **Sağ üst bilet:** Tiyatro bileti (zımba delikleri, koçan, seri no). Pirinç isim plaketi (tıklayınca yeniden adlandır), iki yönlü pirinç TR/EN şalteri, sahne karnesi (G/M, Arena şampiyonluğu, mevcut seri).
- **Seri lideri:** Lobide en uzun seriye sahip oyuncunun üstüne altın bir spot vurur (`Stage.set_gold_target`).
- **Kostüm odası:** Sol pano hafifçe içeri çekilir, karakter sahnenin ortasında tek spotun altına gelir, diğer ışıklar kısılır. 7 şapka, 5 bıyık, 4 papyon ve 8 kumaş rengi var.
- **İzleyici (loca):** Kamera yan duvardaki yaldızlı locaya geçer; sahneye gül, domates (çarpınca ezilir) ya da silindir şapka fırlatılır.
- **Nasıl oynanır:** Eski tiyatro afişi. İpten sarkarak düşer, hafifçe sallanır; Roma rakamlı maddeler var.
- **Sonuç:** "Perde!" panosu; sıralama, seriler, "Bir daha!" ve "Lobiye dön".

---

## 3. Modlar

### Trivia Arena — fiziksel eleme (`modes/trivia_arena.gd`)
1. Soru arkadaki dev panoya düşer. Zemin 4 menteşeli kapağa bölünür (A-B-C-D); şıklar kapakların üstüne yazılıdır.
2. Oyuncular süre bitmeden (8/10/12 sn) doğru kapağa koşar. Omuz atıp birini kapağından düşürmek serbest.
3. Süre dolunca trampet çalar ve yanlış kapaklar açılır; üstündekiler çığlıklarla kuyuya düşer. Hiçbir kapakta durmayanı **vodvil kancası** kulise çeker.
4. Kimse doğru kapakta değilse kapaklar açılmaz, soru yenilenir.
5. Son ayakta kalan kazanır. Kazanan karneye yazılır: galibiyet, Arena şampiyonluğu, seri.

Kapaklar (`stage/trapdoor.gd`) gövdenin kendisini menteşe etrafında döndürür. İlk sürümde ebeveyn düğüm döndürülüyordu ve fizik zemini yerinde kalıyordu; testler bunu yakaladı.

### Conquest Quiz — bölge hakimiyeti (`modes/conquest_quiz.gd`)
1. Sahne 7×4 = 28 karoya bölünür. Her soruda bir hedef karo altın spotla parlar; her 4. soruda 2×2 büyük ödül vardır (rakipten çalabilir).
2. Kenarlarda A-B-C-D pirinç kürsüleri durur. Doğru kürsüye **ilk basan** hedefi kendi rengine boyar.
3. Yanlış kürsü çarpar: oyuncu havaya fırlayıp devrilir ve o soruda bir daha deneyemez.
4. Kendi renginde koşan %15 hızlanır, rakip boyasında %18 yavaşlar. Bu "sıkıştırma" mekaniğinin ilk hali.
5. 12 soru sonunda en çok karosu olan kazanır.

---

## 4. Oyuncular ve bağlantı

| Mod | Durum |
|---|---|
| Yerel: 2 klavye seti + gamepad'ler | ✅ WASD/Boşluk/F · Oklar/Enter/Sağ Shift · gamepad (Ⓐ zıpla, Ⓧ/Ⓑ omuz). Katılmak için tuşa basmak yeterli. |
| Botlar | ✅ Kolay/Normal/Zor. Soruyu okuma süresi, isabet, kararsızlık ve kaos için omuz atma var. |
| **Ev partisi (QR + telefon kumandası)** | ✅ Tek ekran; telefonlar QR ile `/pad` sayfasını açar: sanal joystick, ZIPLA, OMUZ, titreşim. Sunucu: `server/`. |
| Steam online (lobiler, Remote Play Together) | ⏳ v0.3. Hareket girdi ile sürüldüğü için ağ katmanı kontrolcü arayüzünün arkasına takılacak. |

### Ev partisi mimarisi
```
 Telefon (pad.html) ──WS──▶ server/ (Node, ws) ──WS──▶ Oyun (PhoneBridge)
   joystick x,y + tuşlar        oda kodu, aktarım          Controllers.Phone → Plush
   ◀── renk, durum, "elendin", titreşim ─────────────────  notify_player / notify_phones
```
- Telefon girdisi saniyede 30 kez gider. Kısa dokunuşlar mandallanır; oyun basışı karede yakalar.
- Sahne koparsa sunucu odayı 30 sn bekletir ve aynı kodla geri bağlanılır. Telefon koparsa 20 sn içinde aynı koltuğa döner.
- QR, sunucunun `/qr.png` ucundan gelir.

---

## 5. Kamera

`camera/balcony_cam.gd`: İzometrik değil; hafif geniş açılı (44–50°), sahneyi balkondan görür.

- **Cinematic sway:** Aktif oyuncuların ağırlık merkezine yavaşça kayar.
- **El kamerası nefesi:** Gürültü tabanlı hafif salınım.
- **Sarsıntı (trauma):** Kapak açılışında ve büyük ödülde.
- **Kadrajlar:** Lobi (sol pano için sağa kaydırılmış), Arena, Kostüm odası, Loca (sahneye bağlı özel kadraj).

---

## 6. Teknik yol haritası

| Sürüm | İçerik |
|---|---|
| `v1.0-web` | Web prototipi (`web-archive` dalı). Render'da canlı. |
| **`v0.1.0-3d-stage`** (bu sürüm) | Büyük Sahne, pelüş fizik, diegetik arayüz, Trivia Arena, Conquest Quiz, Ev partisi, 47 başsız test |
| v0.2 | Gerçek sanat: pelüş karakter modeli + kumaş dokuları, tiyatro dekor modelleri, müzik, gamepad ile menü gezinme, ayarlar (ses, görüntü kalitesi) |
| v0.3 | Online: sunucu-yetkili fizik + istemci interpolasyonu (ENet → SteamMultiplayerPeer), Steam lobileri, loca sohbeti, iskeletli ragdoll |
| v0.4 | Steamworks: başarımlar, bulut kayıt, mağaza sayfası, Remote Play Together testleri |

### Performans notları
- Hacimsel sis ve gölgeli spotlar Forward+ gerektirir. Zayıf makineler için "Sade" kalite ayarı (v0.2) sisi ve ikincil gölgeleri kapatacak.
- Toz partikülleri GPU'da; dekorlar az çokgenli ve paylaşılan malzemeli.
