# Suno müzik tarifleri — Trivia Arena: The Grand Stage

Hepsinde **Instrumental** açık olsun (sözsüz). "Style of Music" kutusuna aşağıdaki metni yapıştır,
başlığı istediğin gibi koy. Her parçadan 2 sürüm çıkar; beğendiğini indir (MP3 ya da WAV).
Dosyaları `game/tools/audio/suno_in/` klasörüne `<parça>.mp3` adıyla yükle;
`python3 game/tools/audio/music_import.py` döngüyü, uzunluğu ve ses düzeyini ayarlar.

Ortak dünya: 1950'ler televizyon yarışma programı, kadife perdeli eski bir tiyatro,
sahnede keçe pelüş oyuncak karakterler. Sıcak, esprili, zarif; asla karanlık ya da sert değil.

| Dosya | Nerede çalar | Style of Music |
|---|---|---|
| `lobby` | Ana menü, lobi, Karakterim | playful vintage theatre waltz, 3/4, pizzicato strings, celesta and glockenspiel melody, soft brass, warm hall reverb, whimsical toy-box charm, 1950s TV variety show lobby music, relaxed, instrumental |
| `trivia` | Trivia Arena maçı | upbeat 1950s TV game show swing, big band brass stabs, walking upright bass, brushed drums, vibraphone, cheerful and bouncy, catchy quiz show theme, instrumental |
| `think` | Soru sorulurken (gerilim yatağı) | suspenseful quiz show thinking music, ticking pizzicato, soft muted brass, low strings pulse, steady clock-like rhythm, minimal and tense but playful, no melody climax, loopable background, instrumental |
| `conquest` | Conquest (harita/savaş) | epic toy soldier march, board game battle, snare drum march, timpani, heroic french horns and trumpets, playful orchestral adventure, D minor, 100 bpm, instrumental |
| `victory` | Kazanan açıklanınca (kısa) | short triumphant orchestral fanfare, trumpets and timpani, cymbal crash, grand theatre finale, celebratory, ends with a big final chord, instrumental |

İpuçları:
- Parçada şarkı sözü ya da vokal çıkarsa o sürümü kullanma.
- Döngü parçalarının (lobby, trivia, think, conquest) en az 90 saniye olması yeter; intro/outro sorun değil, araç kırpar.
- `victory` için parçanın ilk 8–10 saniyesi kullanılır; güçlü bir açılışı olan sürümü seç.
- Lisans: Suno'nun ücretsiz planında üretilenler ticari kullanıma açık değildir. Steam'de satmak için
  parçaları Pro/Premier aboneliği sırasında üret.
