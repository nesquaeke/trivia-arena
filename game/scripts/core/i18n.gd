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
	"menu.trivia.sub": ["Üç perde: kategori avı, güç turu, son ayakta kalan.", "Three acts: category hunt, power round, last one standing."],
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

	"ticket.champs_s": ["Taç", "Crowns"],
	"ticket.streak_s": ["Seri", "Streak"],
	"ticket.best_s": ["Rekor", "Best"],
	"hint.run": ["koş", "run"],
	"hint.jump": ["zıpla", "jump"],
	"hint.shove": ["omuz at", "shove"],
	"hint.join": ["Katılmak için kendi tuşuna bas:", "Press your own key to join:"],
	"hint.p2": ["2. oyuncu", "Player 2"],
	"key.space": ["Boşluk", "Space"],
	"key.enter": ["Enter", "Enter"],
	"key.arrows": ["Oklar", "Arrows"],
	"key.rshift": ["Sağ Shift", "R-Shift"],
	"key.pad": ["Pad A", "Pad A"],
	"menu.section.play": ["Gösteriler", "Shows"],
	"menu.section.more": ["Kulis", "Backstage"],
	"setup.go": ["Perde açılsın", "Raise the curtain"],
	"setup.rules": ["Üç perde · 12 soru + can turu", "Three acts · 12 questions + health round"],
	"setup.rules_c": ["28 karo · 12 soru", "28 tiles · 12 questions"],

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


	# ── Klasik şov (Trivia Arena, web kuralları)
	"round.1": ["Kategori Avı", "Category Hunt"],
	"round.2": ["Güç Turu", "Power Round"],
	"round.3": ["Son Ayakta Kalan", "Last One Standing"],
	"round.1d": ["4 soru. Doğru cevap 250; üst üste doğrular 500 ve 750 yazar.", "4 questions. 250 a right answer; chains pay 500, then 750."],
	"round.2d": ["Her soruda en hızlı doğru bilen ödül seçer: puan çal ya da sabote et.", "Each question, the fastest right answer picks: steal points or sabotage."],
	"round.3d": ["Puanın cana döner. Yalnızca en hızlı doğru cevap bedelden kurtulur.", "Points become health. Only the fastest right answer escapes the price."],
	"round.1.chip1": ["250 · 250 · 500 · 750", "250 · 250 · 500 · 750"],
	"round.1.chip2": ["Seri bozulursa sıfır", "A miss resets the chain"],
	"round.1.chip3": ["Kolay → Zor", "Easy → Hard"],
	"round.2.chip1": ["400 puan çal", "Steal 400"],
	"round.2.chip2": ["Kurşun · Ters · Buz · Dev kafa", "Lead · Invert · Ice · Big head"],
	"round.2.chip3": ["En hızlı doğru seçer", "Fastest right answer picks"],
	"round.3.chip1": ["Puan = can", "Points = health"],
	"round.3.chip2": ["Bedel her soruda büyür", "The price climbs each question"],
	"round.3.chip3": ["Can biterse kapak açılır", "Hit zero, the hatch opens"],
	"tug.title": ["Kategori halatı", "Category tug-of-war"],
	"tug.sub": ["İstediğin kategorinin dairesine gir ve zıpla! Her zıplayış bir çekiş.", "Get into your category's circle and jump! Every hop is a pull."],
	"tug.phone": ["Kategorinin dairesine koş, ZIPLA'ya bas bas!", "Run into your category's circle, mash JUMP!"],
	"tug.won": ["Bu turun konusu: {cat}", "This round's topic: {cat}"],
	"hud.hp": ["{n} can", "{n} HP"],
	"hud.pts": ["{n} puan", "{n} pts"],
	"hud.q_of": ["Soru {n}/{m}", "Question {n}/{m}"],
	"hud.q_final": ["Can sorusu {n}", "Health question {n}"],
	"hud.stake": ["Bedel: {n} can", "Price: {n} HP"],
	"hud.safe": ["KURTULDU", "SAFE"],
	"hud.fastest": ["En hızlı doğru: {name}", "Fastest right answer: {name}"],
	"hud.nobody": ["Kimse bilemedi", "Nobody got it"],
	"hud.died": ["{names} sahneden düştü!", "{names} dropped through the stage!"],
	"hud.round": ["TUR {n}", "ROUND {n}"],
	"hud.standings": ["Ara sıralama", "Standings"],
	"hud.after": ["{n}. turdan sonra", "After round {n}"],
	"hud.best_combo": ["en iyi seri ×{n}", "best chain ×{n}"],
	"reward.none": ["Kimse doğru bilmedi", "Nobody got it right"],
	"reward.none_sub": ["Bu soruda ödül yok.", "No reward this time."],
	"reward.title": ["{name} ödülünü seçiyor", "{name} picks a reward"],
	"reward.pick_target": ["Kime?", "Who?"],
	"reward.pick_action": ["Ne yapalım?", "What'll it be?"],
	"reward.bot_thinking": ["Kötü planlar kuruluyor…", "Scheming…"],
	"reward.timeout": ["Süre doldu, ödül yandı!", "Time's up, the reward is gone!"],
	"reward.stole": ["{a}, {b} oyuncusundan {n} puan çaldı!", "{a} stole {n} points from {b}!"],
	"reward.sabotaged": ["{a}, {b} oyuncusuna sabotaj: {x}!", "{a} sabotaged {b}: {x}!"],
	"reward.siphon": ["{n} puan çal", "Steal {n}"],
	"reward.siphon_d": ["Seçtiğin rakibin puanından doğrudan senin hanene.", "Straight out of their score, into yours."],
	"reward.phone": ["Ödül senin! Kaydır: seç · ZIPLA: onayla · OMUZ: geri", "Reward's yours! Swipe: choose · JUMP: confirm · SHOVE: back"],
	"reward.how": ["Hareket: seç · Zıpla: onayla · Omuz: geri · ya da tıkla", "Move: choose · Jump: confirm · Shove: back · or click"],
	"debuff.lead": ["Kurşun ayakkabı", "Lead boots"],
	"debuff.invert": ["Ters kumanda", "Inverted controls"],
	"debuff.ice": ["Buz pisti", "Ice rink"],
	"debuff.bighead": ["Dev kafa", "Big head"],
	"debuff.siphon": ["Soygun", "Heist"],
	"debuff.lead.d": ["Bir soru boyunca yarı hızda yürür.", "Walks at half speed for a question."],
	"debuff.invert.d": ["Bir soru boyunca yönler ters.", "Controls flip for a question."],
	"debuff.ice.d": ["Bir soru boyunca ayakları kayar.", "Can't get a grip for a question."],
	"debuff.bighead.d": ["Kafa şişer; en ufak omuzda devrilir.", "Head swells; the lightest shove topples them."],
	"result.points": ["Puan", "Points"],
	"result.hp": ["Can", "Health"],
	"result.correct": ["Doğru", "Correct"],
	"result.combo": ["Seri", "Chain"],
	"result.stolen": ["Çaldığı", "Stolen"],
	"result.out": ["Düştü", "Out"],

	"hud.stake_s": ["Bedel", "Price"],
	"round.kicker": ["Perde", "Act"],
	"result.correct_n": ["{n}/{m} doğru", "{n}/{m} right"],
	"result.stolen_n": ["{n} çaldı", "stole {n}"],
	"wardrobe.kicker": ["Kulis", "Backstage"],
	"house.kicker": ["Telefonla katıl", "Join by phone"],
	"house.code": ["Oda kodu", "Room code"],
	"spectate.kicker": ["Balkon locası", "Balcony box"],
	"howto.r_tug": ["Her perde kategori halatıyla açılır: istediğin kategorinin dairesine gir ve zıpla. En çok çekilen kategori perdenin konusu olur.", "Each act opens with a category tug-of-war: stand in your category's circle and jump. The most-pulled category sets the act."],
	"howto.r_1": ["Perde I · Kategori avı. Süre bitince hangi kapağın üstündeysen cevabın o. Doğrular 250 · 250 · 500 · 750 diye tırmanır.", "Act I · Category hunt. When time's up, the trapdoor you're standing on is your answer. Right answers climb 250 · 250 · 500 · 750."],
	"howto.r_2": ["Perde II · Güç turu. Her soruda en hızlı doğru bilen seçer: rakipten 400 puan çal ya da ona sabotaj yap (kurşun ayakkabı, ters kumanda, buz, dev kafa).", "Act II · Power round. The fastest right answer picks: steal 400 from a rival or sabotage them (lead boots, inverted controls, ice, big head)."],
	"howto.r_3": ["Perde III · Son ayakta kalan. Puanın cana döner. Her soruda yalnız en hızlı doğru kurtulur, diğerleri bedel öder. Canı biten kendi kapağından düşer.", "Act III · Last one standing. Points become health. Each question, only the fastest right answer is safe; everyone else pays. Hit zero and your own trapdoor opens."],
	"howto.r_4": ["Omuz atmak serbest: rakibini doğru kapaktan it!", "Shoving is fair game: knock rivals off the right trapdoor!"],

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
