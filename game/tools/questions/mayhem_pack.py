#!/usr/bin/env python3
"""Mayhem Turu içeriği → data/mayhem.json

  order   Sıralama setleri (Order Chaos): 4 öğe, DOĞRU SIRAYLA yazılır; oyun karıştırır.
          Satır: "TR soru | EN soru | TR ilk-adım | EN ilk-adım | tr~en=etiket ; ..."
          PL/FR/ES metinleri mayhem_i18n.tsv'den gelir (EN metni anahtar; aynı EN iki anlamdaysa "tr:<TR metni>").
  sounds  Kulağına Güven: tools/music/mayhem_sounds.py'nin ürettiği dosyaların adları.

Kullanım: python3 game/tools/questions/mayhem_pack.py
"""
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(ROOT, "..", "..", "data", "mayhem.json"))

OLD = ("Eskiden yeniye sırala!", "Oldest to newest!", "En eski hangisi?", "Which is the oldest?")
SMALL = ("Küçükten büyüğe sırala!", "Smallest to biggest!", "En küçük hangisi?", "Which is the smallest?")
SLOW = ("Yavaştan hızlıya sırala!", "Slowest to fastest!", "En yavaş hangisi?", "Which is the slowest?")
LOW = ("Azdan çoğa sırala!", "Fewest to most!", "En az hangisi?", "Which has the fewest?")
SHORT = ("Kısadan uzuna sırala!", "Shortest to longest!", "En kısa hangisi?", "Which is the shortest?")
NEAR = ("Yakından uzağa sırala!", "Nearest to farthest!", "En yakın hangisi?", "Which is the nearest?")
LIGHT = ("Hafiften ağıra sırala!", "Lightest to heaviest!", "En hafif hangisi?", "Which is the lightest?")
COLD = ("Soğuktan sıcağa sırala!", "Coldest to hottest!", "En soğuk hangisi?", "Which is the coldest?")
QUIET = ("Sessizden gürültülüye sırala!", "Quietest to loudest!", "En sessiz hangisi?", "Which is the quietest?")

ORDER = [
    (OLD, "Piramitler~The Pyramids=MÖ 2560~2560 BC|Kolezyum~The Colosseum=80|Eyfel Kulesi~Eiffel Tower=1889|Burj Khalifa=2010"),
    (OLD, "Tekerlek~The wheel=MÖ 3500~3500 BC|Matbaa~Printing press=1440|Telefon~Telephone=1876|İnternet~The Internet=1983"),
    (OLD, "Dinozorların sonu~End of the dinosaurs=66 milyon yıl önce~66 million years ago|Son mamutlar~Last mammoths=MÖ 2000~2000 BC|Roma'nın kuruluşu~Founding of Rome=MÖ 753~753 BC|Ay'a iniş~Moon landing=1969"),
    (OLD, "Mona Lisa=1503|Don Kişot~Don Quixote=1605|İlk Harry Potter~First Harry Potter=1997|İlk iPhone~First iPhone=2007"),
    (OLD, "Kolomb Amerika'da~Columbus reaches America=1492|ABD'nin bağımsızlığı~US independence=1776|Fransız Devrimi~French Revolution=1789|I. Dünya Savaşı~World War I=1914"),
    (OLD, "İlk sinema gösterimi~First film screening=1895|İlk sesli film~First talking film=1927|Renkli TV yayını~Colour TV broadcasts=1954|YouTube=2005"),
    (OLD, "Pong=1972|Pac-Man=1980|Pokémon=1996|Fortnite=2017"),
    (OLD, "Oxford Üniversitesi~Oxford University=1096|Tenochtitlan (Aztek)~Tenochtitlan (Aztec)=1325|Machu Picchu=1450|Tac Mahal~Taj Mahal=1653"),
    (OLD, "Bisiklet~Bicycle=1817|Otomobil~Car=1886|Uçak~Aeroplane=1903|Ay roketi~Moon rocket=1969"),
    (OLD, "Bach doğdu~Bach born=1685|Mozart doğdu~Mozart born=1756|Chopin doğdu~Chopin born=1810|The Beatles kuruldu~The Beatles formed=1960"),
    (OLD, "Coca-Cola=1886|Nintendo=1889|LEGO=1932|Google=1998"),
    (OLD, "İlk modern Olimpiyat~First modern Olympics=1896|İlk Tour de France~First Tour de France=1903|İlk Dünya Kupası~First World Cup=1930|İlk Avrupa Kupası~First European Cup=1955"),
    (OLD, "Gözlük~Eyeglasses=1286|Mikroskop~Microscope=1590|Teleskop~Telescope=1608|Ampul~Light bulb=1879"),
    (OLD, "Tokyo Olimpiyatı~Tokyo Olympics=1964|Moskova Olimpiyatı~Moscow Olympics=1980|Barselona Olimpiyatı~Barcelona Olympics=1992|Pekin Olimpiyatı~Beijing Olympics=2008"),
    (OLD, "Kopernik'in kitabı~Copernicus's book=1543|Newton'ın elması~Newton's Principia=1687|Darwin'in kitabı~Darwin's Origin=1859|Einstein'ın görelilik~Einstein's relativity=1905"),
    (SMALL, "Atom|Bakteri~Bacterium|Karınca~Ant|Fil~Elephant"),
    (SMALL, "Ay~The Moon|Merkür~Mercury|Dünya~Earth|Jüpiter~Jupiter"),
    (SMALL, "Pinpon topu~Ping-pong ball=4 cm|Tenis topu~Tennis ball=6,7 cm~6.7 cm|Futbol topu~Football=22 cm|Pilates topu~Exercise ball=65 cm"),
    (SMALL, "Vatikan~Vatican City=0,44 km²~0.44 km²|Monako~Monaco=2 km²|Malta=316 km²|Lüksemburg~Luxembourg=2.586 km²~2,586 km²"),
    (SMALL, "Polonya~Poland=312 bin km²~312k km²|İspanya~Spain=506 bin km²~506k km²|Türkiye~Turkey=783 bin km²~783k km²|Arjantin~Argentina=2,78 milyon km²~2.78M km²"),
    (SMALL, "Eyfel Kulesi~Eiffel Tower=330 m|Empire State=443 m|Burj Khalifa=828 m|Everest=8.849 m~8,849 m"),
    (SMALL, "Arktik Okyanusu~Arctic Ocean|Hint Okyanusu~Indian Ocean|Atlas Okyanusu~Atlantic Ocean|Pasifik Okyanusu~Pacific Ocean"),
    (SHORT, "Thames=346 km|Ren~Rhine=1.230 km~1,230 km|Tuna~Danube=2.850 km~2,850 km|Nil~Nile=6.650 km~6,650 km"),
    (SHORT, "Futbol maçı~A football match=90 dk~90 min|Uzun metraj film~A feature film=~2 saat~~2 hours|Bir gün~One day=24 saat~24 hours|Ay'ın turu~The Moon's orbit=27 gün~27 days"),
    (SHORT, "Karasinek~Housefly=4 hafta~4 weeks|Fare~Mouse=2 yıl~2 years|Köpek~Dog=12 yıl~12 years|Dev kaplumbağa~Giant tortoise=100+ yıl~100+ years"),
    (NEAR, "Ay~The Moon=384 bin km~384k km|Mars (en yakın)~Mars (closest)=55 milyon km~55M km|Güneş~The Sun=150 milyon km~150M km|Jüpiter~Jupiter=~600 milyon km~~600M km"),
    (NEAR, "Venüs~Venus|Mars|Satürn~Saturn|Neptün~Neptune"),
    (SLOW, "Salyangoz~Snail=0,05 km/sa~0.05 km/h|Koşan insan~Running human=~20 km/sa~~20 km/h|At~Horse=~70 km/sa~~70 km/h|Çita~Cheetah=~110 km/sa~~110 km/h"),
    (SLOW, "Bisiklet~Bicycle=~20 km/sa~~20 km/h|Otoyolda araba~Car on a motorway=~120 km/sa~~120 km/h|Hızlı tren~High-speed train=~300 km/sa~~300 km/h|Yolcu uçağı~Airliner=~900 km/sa~~900 km/h"),
    (LIGHT, "Tavşan~Rabbit=2 kg|Koyun~Sheep=80 kg|At~Horse=500 kg|Fil~Elephant=5.000 kg~5,000 kg"),
    (LOW, "Norveç~Norway=5,5 milyon~5.5M|Polonya~Poland=37 milyon~37M|İspanya~Spain=48 milyon~48M|Türkiye~Turkey=85 milyon~85M"),
    (LOW, "Kraków=0,8 milyon~0.8M|Barselona~Barcelona=1,6 milyon~1.6M|Madrid=3,3 milyon~3.3M|İstanbul~Istanbul=15,6 milyon~15.6M"),
    (LOW, "Yılan~Snake=0 bacak~0 legs|Tavuk~Chicken=2|Böcek~Insect=6|Örümcek~Spider=8"),
    (LOW, "Keman~Violin=4 tel~4 strings|Gitar~Guitar=6|12 telli gitar~12-string guitar=12|Arp~Harp=47"),
    (LOW, "Tenis (tekler)~Tennis (singles)=1 oyuncu~1 player|Basketbol~Basketball=5|Voleybol~Volleyball=6|Futbol~Football=11"),
    (LOW, "Tavuk~Chicken=0 diş~0 teeth|Kedi~Cat=30|İnsan~Human=32|Köpek~Dog=42"),
    (LOW, "Hawaii dili~Hawaiian=13 harf~13 letters|İngilizce~English=26|Türkçe~Turkish=29|Lehçe~Polish=32"),
    (LOW, "Satranç tahtası sırası~Chessboard row=8|Deste kart~Deck of cards=52|Piyano tuşu~Piano keys=88|Vücuttaki kemik~Bones in the body=206"),
    (COLD, "Buz~Ice=0 °C|İnsan vücudu~Human body=37 °C|Kaynayan su~Boiling water=100 °C|Güneş'in yüzeyi~Sun's surface=5.500 °C~5,500 °C"),
    (QUIET, "Fısıltı~A whisper=30 dB|Konuşma~Conversation=60 dB|Rock konseri~Rock concert=110 dB|Jet motoru~Jet engine=140 dB"),
]

SOUNDS = [
    # id, tür, tr ad, en ad, besteci
    ("ode", "melody", "Neşeye Övgü", "Ode to Joy", "Beethoven"),
    ("twinkle", "melody", "Parla Parla Küçük Yıldız", "Twinkle Twinkle Little Star", ""),
    ("frere", "melody", "Frère Jacques", "Frère Jacques", ""),
    ("birthday", "melody", "İyi ki Doğdun", "Happy Birthday", ""),
    ("elise", "melody", "Für Elise", "Für Elise", "Beethoven"),
    ("fifth", "melody", "5. Senfoni", "Symphony No. 5", "Beethoven"),
    ("jingle", "melody", "Jingle Bells", "Jingle Bells", ""),
    ("mary", "melody", "Mary'nin Küçük Kuzusu", "Mary Had a Little Lamb", ""),
    ("turca", "melody", "Türk Marşı", "Turkish March", "Mozart"),
    ("mountain", "melody", "Dağ Kralının Salonunda", "In the Hall of the Mountain King", "Grieg"),
    ("lullaby", "melody", "Brahms Ninnisi", "Brahms' Lullaby", "Brahms"),
    ("cucaracha", "melody", "La Cucaracha", "La Cucaracha", ""),
    ("danube", "melody", "Mavi Tuna", "The Blue Danube", "Strauss"),
    ("nacht", "melody", "Küçük Bir Gece Müziği", "Eine kleine Nachtmusik", "Mozart"),
    ("wedding", "melody", "Gelin Korosu (Düğün Marşı)", "Bridal Chorus (Here Comes the Bride)", "Wagner"),
    ("oldmac", "melody", "Old MacDonald'ın Çiftliği", "Old MacDonald Had a Farm", ""),
    ("london", "melody", "Londra Köprüsü Yıkılıyor", "London Bridge Is Falling Down", ""),
    ("habanera", "melody", "Habanera (Carmen)", "Habanera (Carmen)", "Bizet"),
    ("greensleeves", "melody", "Greensleeves", "Greensleeves", ""),
    ("siren", "sfx", "Ambulans sireni", "Ambulance siren", ""),
    ("doorbell", "sfx", "Kapı zili", "Doorbell", ""),
    ("phone", "sfx", "Eski telefon zili", "Old telephone ringing", ""),
    ("clock", "sfx", "Duvar saati", "Wall clock", ""),
    ("train", "sfx", "Buharlı tren", "Steam train", ""),
    ("rain", "sfx", "Yağmur", "Rain", ""),
    ("thunder", "sfx", "Gök gürültüsü", "Thunder", ""),
    ("church", "sfx", "Kilise çanı", "Church bell", ""),
    ("cuckoo", "sfx", "Guguklu saat", "Cuckoo clock", ""),
    ("car_horn", "sfx", "Araba kornası", "Car horn", ""),
    ("ship_horn", "sfx", "Gemi düdüğü", "Ship horn", ""),
    ("whistle", "sfx", "Hakem düdüğü", "Referee whistle", ""),
    ("heartbeat", "sfx", "Kalp atışı", "Heartbeat", ""),
    ("popcorn", "sfx", "Patlayan mısır", "Popcorn popping", ""),
    ("typewriter", "sfx", "Daktilo", "Typewriter", ""),
]
XLANGS = ["pl", "fr", "es"]


def load_i18n():
    tab = {}
    with open(os.path.join(ROOT, "mayhem_i18n.tsv"), encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            assert len(p) == 4, line
            tab[p[0]] = dict(zip(XLANGS, p[1:]))
    return tab


def tr_(tab, lang, en, tr=""):
    """EN metnin çevirisi; yoksa (sayı, özel ad) EN aynen"""
    row = tab.get("tr:" + tr) if tr else None
    row = row or tab.get(en)
    return row[lang] if row else en


COMPOSERS = ["Beethoven", "Mozart", "Bach", "Chopin", "Grieg", "Brahms", "Strauss", "Wagner", "Bizet", "Vivaldi"]


def split_lang(s):
    """'tr~en' → (tr, en); tek metin iki dilde aynı"""
    if "~" in s:
        a, b = s.split("~", 1)
        return a.strip(), b.strip()
    return s.strip(), s.strip()


def parse_item(tok):
    name, _, label = tok.partition("=")
    tr, en = split_lang(name)
    ltr, len_ = split_lang(label) if label else ("", "")
    # "~2 saat~~2 hours" gibi yaklaşık işaretli etiketler
    if label.startswith("~") and "~~" in label:
        a, b = label.split("~~", 1)
        ltr, len_ = a, "~" + b
    return {"tr": tr, "en": en, "ltr": ltr, "len": len_}


def main():
    tab = load_i18n()
    order = []
    for (hdr, row) in ORDER:
        items = [parse_item(t) for t in row.split("|")]
        assert len(items) == 4, row
        o = {
            "tr": {"q": hdr[0], "first": hdr[2], "items": [i["tr"] for i in items], "labels": [i["ltr"] for i in items]},
            "en": {"q": hdr[1], "first": hdr[3], "items": [i["en"] for i in items], "labels": [i["len"] for i in items]},
        }
        for l in XLANGS:
            o[l] = {"q": tr_(tab, l, hdr[1]), "first": tr_(tab, l, hdr[3]),
                    "items": [tr_(tab, l, i["en"], i["tr"]) for i in items],
                    "labels": [tr_(tab, l, i["len"]) for i in items]}
        order.append(o)
    sounds = []
    for s in SOUNDS:
        row = {"id": s[0], "kind": s[1], "tr": s[2], "en": s[3], "composer": s[4]}
        for l in XLANGS:
            row[l] = tr_(tab, l, s[3])
        sounds.append(row)
    for s in sounds:
        path = os.path.join(ROOT, "..", "..", "assets", "audio", "mayhem", s["id"] + ".ogg")
        assert os.path.exists(path), "ses dosyası yok: " + s["id"]
    data = {"version": 1, "order": order, "sounds": sounds, "composers": COMPOSERS}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("sıralama: %d · ses: %d (%d melodi)" % (len(order), len(sounds), sum(1 for s in sounds if s["kind"] == "melody")))


if __name__ == "__main__":
    main()
