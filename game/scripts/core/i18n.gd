extends Node
## İki dilli sözlük (TR/EN). Tüm arayüz metinleri buradan gelir.
## Kullanım: I18n.t("menu.trivia"), I18n.t("hud.alive", {"n": 3})

signal changed(lang: String)

var lang := "tr"

const S := {
	# ── başlık / genel
	"title.top": ["TRIVIA", "TRIVIA"],
	"title.bottom": ["ARENA", "ARENA"],
	"title.tagline": ["Büyük Sahne", "The Grand Stage"],
	"common.back": ["Geri", "Back"],
	"common.done": ["Tamam", "Done"],
	"common.start": ["Perde açılsın!", "Raise the curtain!"],
	"common.soon": ["YAKINDA", "COMING SOON"],

	# ── sol panel
	"menu.trivia": ["Trivia Arena", "Trivia Arena"],
	"menu.trivia.sub": ["Doğru şıkka koş. Yanlış kapak açılır.", "Run to the right answer. Wrong trapdoors open."],
	"menu.conquest": ["Conquest Quiz", "Conquest Quiz"],
	"menu.conquest.sub": ["Doğru kürsüye ilk sen bas, sahneyi boya.", "Hit the right podium first, paint the stage."],
	"menu.customize": ["Karakterim", "My Character"],
	"menu.customize.sub": ["Şapka, bıyık, papyon, renk", "Hats, moustaches, bow ties, colours"],
	"menu.spectate": ["İzleyici olarak katıl", "Join as spectator"],
	"menu.spectate.sub": ["Locadan izle, sahneye gül at", "Watch from the box, throw roses"],
	"menu.howto": ["Nasıl oynanır?", "How to play"],
	"menu.howto.sub": ["Kısa afiş rehberi", "The playbill, in brief"],
	"menu.quit": ["Çıkış", "Exit"],

	# ── profil bileti
	"ticket.admit": ["GİRİŞ BİLETİ", "ADMIT ONE"],
	"ticket.row": ["SIRA", "ROW"],
	"ticket.seat": ["KOLTUK", "SEAT"],
	"ticket.record": ["SAHNE KARNESİ", "STANDING RECORD"],
	"ticket.wl": ["G / M", "W / L"],
	"ticket.champs": ["Arena şampiyonluğu", "Arena championships"],
	"ticket.streak": ["Mevcut seri", "Current streak"],
	"ticket.best": ["En iyi seri", "Best streak"],
	"ticket.rename": ["Adını değiştirmek için tıkla", "Click to rename"],

	# ── ev partisi (telefon kumandası)
	"menu.house": ["Ev partisi", "House party"],
	"menu.house.sub": ["QR'ı okut, telefonun kumanda olsun", "Scan the QR, your phone is the controller"],
	"house.title": ["Ev Partisi", "House Party"],
	"house.scan": ["Telefon kamerasıyla QR'ı okut ya da şu adrese gir ve kodu yaz:", "Scan the QR with your phone camera, or open this address and type the code:"],
	"house.phones": ["Bağlı telefonlar: {n}", "Phones connected: {n}"],
	"house.none": ["Henüz telefon yok", "No phones yet"],
	"house.connecting": ["Sunucuya bağlanılıyor…", "Connecting to the server…"],
	"house.error": ["Sunucuya ulaşılamadı, yeniden deneniyor…", "Can't reach the server, retrying…"],
	"house.server": ["Sunucu adresi", "Server address"],
	"house.connect": ["Bağlan", "Connect"],
	"house.close": ["Kapat", "Close"],
	"house.status_q": ["Soru {n}: doğru kapağa koş!", "Question {n}: run to the right trapdoor!"],
	"house.status_lobby": ["Lobidesin. Koş, zıpla, omuz at!", "You're in the lobby. Run, jump, shove!"],
	"house.status_win": ["Kazandın! Sahne senin!", "You won! The stage is yours!"],

	# ── lobi ipuçları
	"lobby.join": ["Katıl: WASD + Boşluk  ·  Oklar + Enter  ·  Gamepad Ⓐ", "Join: WASD + Space  ·  Arrows + Enter  ·  Gamepad Ⓐ"],
	"lobby.controls": ["Koş: WASD  ·  Zıpla: Boşluk  ·  Omuz at: F", "Run: WASD  ·  Jump: Space  ·  Shove: F"],
	"lobby.controls2": ["2. oyuncu: Oklar · Enter zıpla · Sağ Shift omuz", "Player 2: Arrows · Enter jump · Right Shift shove"],
	"lobby.leader": ["{name} en uzun seride: {n}", "{name} holds the longest streak: {n}"],

	# ── mod kurulum
	"setup.title": ["Bu geceki gösteri", "Tonight's performance"],
	"setup.bots": ["Bot oyuncular", "Bot players"],
	"setup.level": ["Bot zorluğu", "Bot difficulty"],
	"setup.level.easy": ["Kolay", "Easy"],
	"setup.level.normal": ["Normal", "Normal"],
	"setup.level.hard": ["Zor", "Hard"],
	"setup.timer": ["Cevap süresi", "Answer time"],
	"setup.seconds": ["{n} sn", "{n} s"],
	"setup.players": ["Sahnede: {n} oyuncu", "On stage: {n} players"],

	# ── karakter atölyesi
	"wardrobe.title": ["Kostüm Odası", "Costume Room"],
	"wardrobe.color": ["Kumaş", "Fabric"],
	"wardrobe.hat": ["Şapka", "Hat"],
	"wardrobe.mustache": ["Bıyık", "Moustache"],
	"wardrobe.bowtie": ["Papyon", "Bow tie"],
	"wardrobe.name": ["Sahne adı", "Stage name"],

	# ── kostümler
	"look.none": ["Yok", "None"],
	"look.tophat": ["Silindir", "Top hat"],
	"look.bowler": ["Melon", "Bowler"],
	"look.fez": ["Fes", "Fez"],
	"look.boater": ["Hasır", "Boater"],
	"look.crown": ["Taç", "Crown"],
	"look.cone": ["Parti külahı", "Party cone"],
	"look.handlebar": ["Kıvrık", "Handlebar"],
	"look.chevron": ["Fırça", "Chevron"],
	"look.pencil": ["Kalem", "Pencil"],
	"look.walrus": ["Mors", "Walrus"],
	"look.classic": ["Klasik", "Classic"],
	"look.dotted": ["Puantiyeli", "Polka"],
	"look.big": ["Kocaman", "Oversized"],
	"color.mustard": ["Hardal", "Mustard"],
	"color.butter": ["Tereyağı", "Butter"],
	"color.tangerine": ["Mandalina", "Tangerine"],
	"color.rose": ["Gül", "Rose"],
	"color.mint": ["Nane", "Mint"],
	"color.sky": ["Gök", "Sky"],
	"color.lilac": ["Leylak", "Lilac"],
	"color.charcoal": ["Kömür", "Charcoal"],

	# ── izleyici
	"spectate.title": ["Loca", "The Box"],
	"spectate.hint": ["Sahneye bir şey fırlat:", "Throw something on stage:"],
	"spectate.rose": ["Gül", "Rose"],
	"spectate.tomato": ["Domates", "Tomato"],
	"spectate.hat": ["Şapka", "Hat"],
	"spectate.leave": ["Locadan çık", "Leave the box"],

	# ── nasıl oynanır afişi
	"howto.head": ["BU GECE", "TONIGHT"],
	"howto.title": ["Nasıl Oynanır", "How to Play"],
	"howto.t1": ["Soru arkadaki dev panoya düşer.", "The question drops onto the giant board."],
	"howto.t2": ["Zemin dört kapağa bölünür: A · B · C · D.", "The floor splits into four trapdoors: A · B · C · D."],
	"howto.t3": ["Süre bitmeden doğru şıkkın kapağına koş.", "Run to the right answer before time runs out."],
	"howto.t4": ["Yanlış kapaklar açılır; üstündeki sahnenin altına düşer.", "Wrong trapdoors open; whoever stands on them drops below."],
	"howto.t5": ["Omuz at, it, kapağından düşür. Son ayakta kalan kazanır.", "Shove, bump, knock them off. Last one standing wins."],
	"howto.c1": ["Sahne 28 karoya bölünür; her soruda hedef karo altın spotla parlar.", "The stage splits into 28 tiles; each question lights a target tile in gold."],
	"howto.c2": ["Kenarlarda A · B · C · D kürsüleri var. Doğru kürsüye ilk basan hedefi kendi rengine boyar.", "Podiums A · B · C · D line the edges. First onto the right podium paints the target."],
	"howto.c3": ["Yanlış kürsü çarpar: yere serilirsin, o soruda bir daha deneyemezsin.", "The wrong podium zaps you: you're floored and out for that question."],
	"howto.c4": ["Kendi renginde hızlanırsın, rakip boyasında yavaşlarsın. Her 4. soru 2×2 büyük ödül.", "You speed up on your colour and slow down on theirs. Every 4th question is a 2×2 jackpot."],
	"howto.c5": ["12 soru sonunda en çok karosu olan kazanır.", "After 12 questions, most tiles wins."],
	"conquest.run": ["Doğru kürsüye ilk sen bas!", "Be first onto the right podium!"],
	"conquest.big": ["Büyük ödül: 2×2 karo!", "Jackpot: a 2×2 block!"],
	"conquest.phone": ["Soru {n}: doğru kürsüye koş!", "Question {n}: run to the right podium!"],
	"conquest.claim": ["{name} {n} karo boyadı!", "{name} painted {n} tile(s)!"],
	"conquest.nobody": ["Kimse doğru kürsüye ulaşamadı.", "Nobody reached the right podium."],
	"conquest.winner": ["{name} sahneye hükmediyor: {n} karo!", "{name} rules the stage: {n} tiles!"],
	"howto.keys": ["WASD koş · Boşluk zıpla · F omuz at", "WASD run · Space jump · F shove"],
	"howto.close": ["Afişi kaldır", "Raise the poster"],

	# ── Trivia Arena
	"arena.round": ["Soru {n}", "Question {n}"],
	"arena.alive": ["Sahnede {n} kişi", "{n} left on stage"],
	"arena.run": ["Doğru kapağa koş!", "Run to the right trapdoor!"],
	"arena.open": ["Kapaklar açılıyor!", "Trapdoors opening!"],
	"arena.correct": ["Doğru cevap: {x}", "Correct answer: {x}"],
	"arena.nobody": ["Kimse bilemedi, kapaklar kapalı kalıyor. Tekrar!", "Nobody got it. Trapdoors stay shut. Again!"],
	"arena.fell": ["{names} düştü!", "{names} fell!"],
	"arena.winner": ["{name} son ayakta kalan!", "{name} is the last one standing!"],
	"arena.draw": ["Sahne boşaldı, kazanan yok!", "The stage is empty. No winner!"],
	"arena.back": ["Lobiye dön", "Back to the lobby"],
	"arena.again": ["Bir daha!", "Encore!"],
	"arena.pit": ["Kuyu", "The pit"],
	"arena.lobby_board": ["BU GECE · TRIVIA ARENA · SON AYAKTA KALAN KAZANIR", "TONIGHT · TRIVIA ARENA · LAST ONE STANDING WINS"],

	# ── sonuç
	"result.title": ["Perde!", "Curtain!"],
	"result.place": ["{n}.", "{n}."],
}

func _ready() -> void:
	lang = "tr"

func t(key: String, args: Dictionary = {}) -> String:
	var row: Array = S.get(key, [])
	var out: String = key if row.is_empty() else String(row[1 if lang == "en" else 0])
	for k in args:
		out = out.replace("{" + String(k) + "}", str(args[k]))
	return out

func set_lang(l: String) -> void:
	if l != "tr" and l != "en":
		return
	if l == lang:
		return
	lang = l
	changed.emit(lang)

func toggle() -> void:
	set_lang("en" if lang == "tr" else "tr")

## Test: her anahtarın iki dili de dolu mu?
func missing_keys() -> Array:
	var bad := []
	for k in S:
		var row: Array = S[k]
		if row.size() != 2 or String(row[0]).is_empty() or String(row[1]).is_empty():
			bad.append(k)
	return bad
