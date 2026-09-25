# ElevenLabs ses üretimi

Oyunun seslerini ElevenLabs ile profesyonel hâle getirme planı. Kullanıcı kontrolü
tamamen Claude'a bıraktı: öncelik sırasıyla, temaya uygun üret, kaliteyi kendin denetle.

- `sound_plan.py`: 194 ses, öncelik sırasıyla (1 en sık duyulan efektler → 6 PL/FR/ES sunucu) ve tema tarifleri
- `elevenlabs_gen.py`: üretici (kredi bütçesini izler, kaldığı yerden devam eder, en iyi seçeneği seçer)
- Çıktı `game/assets/audio_pro/<tür>/<id>.ogg`; oyun AudioPack ile otomatik kullanır. Diğer seçenekler `alts/` içinde.

## Yeni oturumda yapılacaklar

1. `ELEVENLABS_API_KEY` ortam değişkeni ve `api.elevenlabs.io` ağ izni olmalı.
2. `python3 game/tools/audio/elevenlabs_gen.py --only tick` ile tek ses üret, kredi harcamasını gör.
3. `python3 game/tools/audio/elevenlabs_gen.py --reserve 300` ile tamamını üret (bütçe biterse durur).
4. `godot --headless --path game --import`, testler (`res://tests/tests.tscn`), commit, dal + main'e push.
5. Kullanıcıya hangi seslerin değiştiğini ve kalan krediyi Türkçe bildir.

Hesap 10.000 kredi (ücretsiz plan olabilir: ticari kullanım için Starter+ gerekir, kullanıcıyı uyar).
Müzik bu plana dahil değil (ücretli plan ister); müzikler FluidR3 örnekleriyle üretiliyor.
