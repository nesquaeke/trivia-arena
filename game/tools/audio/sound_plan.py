"""Trivia Arena ses planı: ElevenLabs ile üretilecek her ses, öncelik sırasıyla.

Tema: "Büyük Sahne" — kadife perdeli eski bir tiyatro, 1950'ler televizyon yarışma
programı havası, sahnede keçe/pelüş oyuncak karakterler. Sesler sıcak, oyuncaklı,
hafif karikatür; sert ya da gerçekçi şiddet yok.

Her kayıt: id, tür, öncelik (1 en önemli), süre (sn, oyunun zamanlamasına uygun),
seçenek sayısı ve İngilizce tarif (ElevenLabs İngilizce tarifle en iyi sonucu verir).
Türler: sfx (oyun efekti), mayhem (Kulağına Güven sesi), voice (sunucu repliği).
Çıktı: game/assets/audio_pro/<tür>/<id>.ogg — oyun bunları AudioPack ile otomatik kullanır.
"""

# ortak tema eki: her efekt tarifinin sonuna eklenir
THEME = "Warm vintage theatre game show atmosphere, playful plush-toy cartoon feel, clean studio quality, no music, no speech."

# (id, öncelik, süre, seçenek, tarif)
SFX = [
    # ── 1: en sık duyulanlar (her maçta onlarca kez) ──────────────────
    ("tick", 1, 0.5, 2, "A single crisp wooden tick of a vintage game show countdown clock, dry, very short."),
    ("ding", 1, 1.2, 2, "Bright cheerful correct-answer chime of a 1950s TV quiz show, sparkling bells and glockenspiel, short and triumphant."),
    ("buzz", 1, 0.7, 2, "Retro TV quiz show wrong-answer buzzer, a short comedic double 'eh-eh' buzz."),
    ("whoosh", 1, 0.8, 2, "Quick theatrical whoosh, a velvet curtain swish passing by, short."),
    ("jump", 1, 0.5, 2, "A soft springy cartoon hop of a small plush teddy bear jumping, light boing with a fabric flutter, very short."),
    ("land", 1, 0.5, 2, "Soft muffled thump of a plush stuffed toy landing on a wooden theatre stage, very short."),
    ("bump", 1, 0.5, 2, "Two plush stuffed toys bumping into each other, a squishy soft pillow bump, very short."),
    ("shove", 1, 0.5, 2, "A playful cartoon shove, quick fabric swoosh ending in a padded pillow push, short."),
    ("click", 1, 0.5, 1, "A soft vintage brass button click, subtle, very short user interface sound."),
    ("ui_hover", 1, 0.5, 1, "A tiny soft brass bell tink, elegant and subtle menu hover sound, very short."),
    ("ui_confirm", 1, 0.8, 1, "Warm elegant rising two-note chime, soft brass bells, a menu confirm sound, short."),
    ("ui_back", 1, 0.8, 1, "Gentle descending two-note chime, soft brass bells, a menu back sound, short."),
    ("scream", 1, 1.4, 2, "A comedic high-pitched cartoon scream of a tiny plush toy falling down a deep hole, fading away, funny, no words."),
    ("trapdoor", 1, 1.0, 2, "A wooden theatre stage trapdoor springing open, creak and clunk with a spring rattle, cartoon style."),
    ("applause", 1, 2.4, 2, "Enthusiastic theatre audience applause with a few whistles and cheers, warm concert hall."),
    ("coin", 1, 1.0, 2, "Cheerful reward sound: gold coins clinking with a bright sparkle chime, short."),
    # ── 2: büyük anlar ───────────────────────────────────────────────
    ("fanfare", 2, 2.0, 2, "Short triumphant brass fanfare for a quiz show winner, trumpets and a timpani hit."),
    ("drumroll", 2, 1.8, 1, "A tense snare drum roll building up in volume, vintage game show suspense, ends abruptly."),
    ("sting", 2, 2.0, 1, "A dramatic orchestral stinger hit, brass and strings with a timpani boom, theatrical reveal."),
    ("cheer", 2, 3.0, 1, "A happy theatre crowd cheering and clapping, excited 'yay', warm hall."),
    ("ooh", 2, 2.5, 1, "A theatre audience going 'ooooh' together in amazement, rising, warm hall."),
    ("aww", 2, 2.4, 1, "A theatre audience going 'awww' together in disappointment, falling, warm hall."),
    ("curtain", 2, 2.2, 1, "Heavy red velvet theatre curtains sweeping open with a soft rustle and a pulley rattle."),
    ("oof", 2, 0.6, 2, "A cute comedic 'oof' grunt of a small plush toy character getting knocked over, no words."),
    ("thud", 2, 0.5, 1, "A soft heavy thud of a stuffed toy hitting a wooden floor, padded, short."),
    ("pop", 2, 0.5, 1, "A cute cartoon pop, like a cork popping out of a toy bottle, very short."),
    ("heartbeat", 2, 1.0, 1, "Two deep tense heartbeats, suspenseful, cinematic."),
    ("stamp", 2, 0.8, 1, "A wooden flag pole stamped firmly into a wooden board with a small metal ring, short."),
    ("claim", 2, 1.4, 1, "Short heroic two-note brass call with a small bell ring, territory captured, board game."),
    ("page", 2, 0.7, 1, "A single paper poster page flip, crisp, short."),
    ("roll", 2, 2.0, 1, "A snare drum tremolo roll rising in tension, ending with a soft cymbal swell."),
    # ── 3: Conquest savaşı ──────────────────────────────────────────
    ("war_drum", 3, 1.8, 1, "One powerful deep war drum hit, taiko and timpani, epic board game battle."),
    ("war_horn", 3, 3.0, 1, "A medieval war horn call, two long brassy notes, epic but toy-like board game battle."),
    ("collapse", 3, 3.5, 1, "A toy castle tower collapsing: stone blocks crumbling, rumble and falling rubble, cartoonish, not violent."),
    # ── 3: Mayhem anları (kaos, kapılar, yakınlaştırma, ödüller) ─────
    ("chaos_alarm", 3, 1.6, 2, "A comedic cartoon warning alarm: a wobbly rising siren whistle with a bike horn honk, chaos is coming, playful."),
    ("chaos_ice", 3, 1.4, 2, "Magical ice freezing over a floor: crisp crackling frost spreading with a sparkly shimmer, cartoon style."),
    ("chaos_bighead", 3, 1.2, 2, "A cartoon balloon inflating quickly with a rubbery stretch and a funny squeak, a head growing huge."),
    ("chaos_invert", 3, 1.2, 2, "A dizzy cartoon reverse warp: a descending then rising wobbly slide whistle with a swirly whoosh, everything flipped."),
    ("chaos_tiny", 3, 1.0, 2, "A cartoon shrinking sound: a fast descending sparkly slide whistle ending in a tiny cute squeak."),
    ("chaos_moving", 3, 1.4, 2, "Wooden theatre stage machinery shifting: gears clanking, a rope pulley and a sliding wooden rumble, cartoon style."),
    ("dizzy", 3, 1.4, 2, "A cartoon dizzy daze: little birds tweeting and circling with a soft wobbly ring, after a bonk on the head."),
    ("door_drop", 3, 0.6, 2, "A small wooden door frame dropping onto a wooden theatre stage and bouncing once, a hollow clunk, short."),
    ("door_open", 3, 1.2, 2, "A small wooden door swinging open with a short creak, revealing a warm magical golden shimmer."),
    ("door_rattle", 3, 0.7, 2, "A locked small wooden door rattling and shaking, a quick comedic handle jiggle, short."),
    ("zoom", 3, 1.2, 1, "A vintage camera lens zooming: a smooth mechanical whirr with a soft click, short."),
    ("award", 3, 0.9, 2, "A sparkling award reveal: a bright glockenspiel flourish with a soft shimmer, a trophy appearing, short."),
    ("join", 3, 0.6, 2, "A cheerful cartoon pop with a tiny rising bell, a new player joining the game, very short."),
]

# Mayhem "Kulağına Güven": oyuncu sesi tanımaya çalışır — tanıdık ve net olmalı (tema eki yok)
MAYHEM = [
    ("siren", 4, 5.0, 1, "An ambulance siren passing by, clear and recognizable, no other sounds."),
    ("doorbell", 4, 3.5, 1, "A classic home doorbell ringing 'ding-dong' twice, clear and recognizable."),
    ("phone", 4, 4.0, 1, "An old rotary telephone ringing with a mechanical bell, two rings, clear and recognizable."),
    ("clock", 4, 4.0, 1, "A wall clock ticking steadily, tick-tock, clear and recognizable."),
    ("train", 4, 4.5, 1, "A steam train chugging and blowing its whistle, clear and recognizable."),
    ("rain", 4, 4.5, 1, "Steady rain falling on a window and roof, clear and recognizable."),
    ("thunder", 4, 5.0, 1, "A loud thunder clap followed by a long rumble, clear and recognizable."),
    ("church", 4, 6.0, 1, "A large church bell tolling three times, clear and recognizable."),
    ("cuckoo", 4, 3.5, 1, "A cuckoo clock calling 'cuckoo' three times, clear and recognizable."),
    ("car_horn", 4, 2.0, 1, "A car horn honking twice in traffic, clear and recognizable."),
    ("ship_horn", 4, 4.5, 1, "A big ship's foghorn blowing one long deep blast, clear and recognizable."),
    ("whistle", 4, 2.4, 1, "A football referee whistle: two short blasts and one long blast, clear and recognizable."),
    ("heartbeat", 4, 3.2, 1, "A human heartbeat, steady lub-dub, clear and recognizable."),
    ("popcorn", 4, 4.0, 1, "Popcorn popping in a pot, many quick pops, clear and recognizable."),
    ("typewriter", 4, 3.0, 1, "An old mechanical typewriter typing quickly, ending with the carriage return bell ding."),
]

# Sunucu replikleri: öncelik 5 (TR, EN), 6 (PL, FR, ES). Metinler tools/voice/narrate.py'den gelir.
VOICE_TIERS = {"tr": 5, "en": 5, "pl": 6, "fr": 6, "es": 6}

# Sunucu sesi: coşkulu, sıcak, eski usul yarışma sunucusu. Sırayla denenir (ElevenLabs hazır sesleri);
# TA_VOICE_ID ortam değişkeni verilirse o kullanılır.
VOICE_CANDIDATES = [
    ("nPczCjzI2devNBz1zQrb", "Brian"),     # derin, sıcak anlatıcı
    ("JBFqnCBsd6RMkjVDRZzb", "George"),    # sıcak, tiyatrovari
    ("onwK4e9ZLuTAKqWW03F9", "Daniel"),    # otoriter sunucu
    ("pNInz6obpgDQGcFmaJgB", "Adam"),
]
VOICE_SETTINGS = {"stability": 0.38, "similarity_boost": 0.8, "style": 0.5, "use_speaker_boost": True}
