# Profesyonel ses paketi

Oyundaki her ses kodla üretilir. Aynı ada sahip bir ses dosyası koyarsan oyun onu kullanır. Dosya bırakılmayan sesler eskisi gibi çalar.

## Nereye?

- **Derlemeden denemek için:** Oyunda Ayarlar > Ses > **Ses paketi: Klasörü aç**. Açılan `audio` klasöründe `sfx`, `music`, `mayhem`, `voice/tr` gibi alt klasörler var. Dosyayı ilgili klasöre bırak ve oyunu yeniden başlat.
- **Oyunla birlikte dağıtmak için:** Dosyayı bu klasöre koy: `game/assets/audio_pro/<tür>/<ad>.ogg`. Godot içe aktarır, dışa aktarımda oyuna girer.

Biçimler: `.ogg` (önerilen), `.wav`, `.mp3`. `lobby`, `conquest`, `trivia` ve `think` müzikleri döngüde çalar.

## Adlar

### sfx (efektler)
- `jump`
- `land`
- `shove`
- `bump`
- `oof`
- `trapdoor`
- `scream`
- `tick`
- `ding`
- `buzz`
- `applause`
- `drumroll`
- `whoosh`
- `fanfare`
- `click`
- `thud`
- `war_drum`
- `war_horn`
- `collapse`
- `sting`
- `stamp`
- `roll`
- `claim`
- `ooh`
- `aww`
- `cheer`
- `ui_hover`
- `ui_confirm`
- `ui_back`
- `coin`
- `curtain`
- `heartbeat`
- `page`

### music (müzik)
- `conquest`
- `lobby`
- `think`
- `trivia`
- `victory`

### mayhem (Kulağına Güven turundaki sesler)
- `ode`: Ode to Joy
- `twinkle`: Twinkle Twinkle Little Star
- `frere`: Frère Jacques
- `birthday`: Happy Birthday
- `elise`: Für Elise
- `fifth`: Symphony No. 5
- `jingle`: Jingle Bells
- `mary`: Mary Had a Little Lamb
- `turca`: Turkish March
- `mountain`: In the Hall of the Mountain King
- `lullaby`: Brahms' Lullaby
- `cucaracha`: La Cucaracha
- `danube`: The Blue Danube
- `nacht`: Eine kleine Nachtmusik
- `wedding`: Bridal Chorus (Here Comes the Bride)
- `oldmac`: Old MacDonald Had a Farm
- `london`: London Bridge Is Falling Down
- `habanera`: Habanera (Carmen)
- `greensleeves`: Greensleeves
- `siren`: Ambulance siren
- `doorbell`: Doorbell
- `phone`: Old telephone ringing
- `clock`: Wall clock
- `train`: Steam train
- `rain`: Rain
- `thunder`: Thunder
- `church`: Church bell
- `cuckoo`: Cuckoo clock
- `car_horn`: Car horn
- `ship_horn`: Ship horn
- `whistle`: Referee whistle
- `heartbeat`: Heartbeat
- `popcorn`: Popcorn popping
- `typewriter`: Typewriter

### voice/tr, voice/en, voice/pl, voice/fr, voice/es (sunucu replikleri)
- `act1_arena`
- `act1_cq`
- `act2_arena`
- `act2_cq`
- `act3_arena`
- `act3_cq`
- `applause`
- `attack`
- `capture`
- `castle_fall`
- `castle_pick`
- `correct`
- `duel`
- `eliminated`
- `estimate`
- `five`
- `last_round`
- `nobody`
- `question`
- `ready`
- `repel`
- `reveal`
- `sabotage`
- `spot_on`
- `steal`
- `tie`
- `tower`
- `welcome`
- `winner`

Sunucu cümlelerinin metinleri `tools/voice/narrate.py` içinde. Seslendirme sanatçısına bu listeyi ver ya da bir yapay zekâ seslendirme aracıyla (ör. ElevenLabs) aynı adlarla kaydet.

## Nereden bulunur?

- **Ücretsiz (CC0, atıf gerekmez):** Kenney.nl ses paketleri (Interface, Impact, Casino, Music Jingles), Sonniss GDC Game Audio Bundle, freesound.org'da CC0 filtresiyle arama.
- **Yapay zekâ ile üretim:** ElevenLabs Sound Effects (efekt ve sunucu sesi), Suno ya da Udio (müzik; ticari kullanım için ücretli plan gerekir).
- **Satın alma:** Epidemic Sound, Artlist, Soundly, ya da itch.io'daki oyun ses paketleri.

Lisansı her zaman kontrol et. Steam'de satılacak bir oyunda ticari kullanıma izin veren lisans gerekir.
