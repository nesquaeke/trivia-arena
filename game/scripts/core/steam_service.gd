extends Node
## Steam köprüsü. GodotSteam (GDExtension) kuruluysa Steam'i kullanır; değilse
## oyun aynen çalışır, başarımlar profilde saklanır ve oyun içinde gösterilir.
##
## Kurulum: tools/steam/README.md (GodotSteam'i addons/ altına koy, steam_appid.txt).
##
##   SteamService.unlock("CASTLE_BREAKER")      başarım
##   SteamService.add_stat("matches", 1)        istatistik
##   SteamService.presence("lobby")             arkadaş listesindeki durum
##   SteamService.invite_remote_play()          Remote Play Together daveti
##   SteamService.host_lobby()                  arkadaşlara açık lobi + davet penceresi
##
## Çevrimiçi oyun yolu: Remote Play Together. Steam oyunu arkadaşa yayınlar,
## arkadaşın klavye/gamepad'i bizim oyunda yerel bir oyuncu gibi görünür. Oyun
## zaten çok girişli (2 klavye + 8 gamepad + telefon) olduğu için ek ağ kodu
## gerekmez. Lobi, davet ve "katıl" isteği bu dosyada.

signal achievement_unlocked(id: String, title: String)
signal lobby_ready(lobby_id: int)
signal status_changed(text: String)

## Test için Spacewar (480). Kendi App ID'n gelince steam_appid.txt'yi ve bunu değiştir.
const APP_ID := 480

## Başarımlar: id -> [TR başlık, EN başlık, TR açıklama, EN açıklama]
## Steamworks'te aynı id'lerle tanımla (tools/steam/achievements.json).
const ACHIEVEMENTS := {
	"FIRST_WIN": ["İlk Alkış", "First Applause", "Bir maç kazan.", "Win a match."],
	"TRIVIA_CHAMP": ["Son Ayakta Kalan", "Last One Standing", "Trivia Arena'yı kazan.", "Win Trivia Arena."],
	"CONQUEROR": ["Anadolu'nun Hâkimi", "Master of Anatolia", "Conquest'i kazan.", "Win a Conquest match."],
	"CASTLE_BREAKER": ["Kale Yıkan", "Castle Breaker", "Bir rakibin kalesini düşür.", "Topple a rival's castle."],
	"SPOT_ON": ["Tam İsabet", "Spot On", "Bir tahmini tam doğru bil.", "Guess an estimate exactly."],
	"HEIST": ["Kasa Soygunu", "The Heist", "Güç turunda puan çal.", "Steal points in the power round."],
	"STREAK_3": ["Üçleme", "Hat Trick", "Üst üste üç maç kazan.", "Win three matches in a row."],
	"HOUSE_PARTY": ["Ev Partisi", "House Party", "Telefonla katılan biriyle maç oyna.", "Play a match with a phone player."],
	"FULL_HOUSE": ["Tam Kadro", "Full House", "Sekiz kişilik bir maç oyna.", "Play an eight-player match."],
	"WARDROBE": ["Kostüm Provası", "Dress Rehearsal", "Karakterini değiştir.", "Change your look."],
	"MARATHON": ["Sahnenin Demirbaşı", "Stage Regular", "25 maç oyna.", "Play 25 matches."],
	"UNTOUCHED": ["Dokunulmaz", "Untouchable", "Hiç toprak kaybetmeden Conquest kazan.", "Win Conquest without losing any land."],
}

var available := false           # GodotSteam yüklü ve Steam açık
var steam_id := 0
var persona := ""
var lobby_id := 0
var _s: Object = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		_log("GodotSteam yok: yerel mod")
		return
	_s = Engine.get_singleton("Steam")
	var res = _s.call("steamInitEx")
	var ok := false
	if typeof(res) == TYPE_DICTIONARY:
		ok = int(res.get("status", 1)) == 0
		_log("steamInitEx: %s" % str(res.get("verbal", res)))
	elif typeof(res) == TYPE_BOOL:
		ok = res
	if not ok:
		_s = null
		return
	available = true
	steam_id = int(_s.call("getSteamID"))
	persona = String(_s.call("getPersonaName"))
	_connect("lobby_created", _on_lobby_created)
	_connect("lobby_joined", _on_lobby_joined)
	_connect("join_requested", _on_join_requested)
	if _s.has_method("requestCurrentStats"):
		_s.call("requestCurrentStats")
	presence("lobby")

func _connect(sig: String, cb: Callable) -> void:
	if _s and _s.has_signal(sig) and not _s.is_connected(sig, cb):
		_s.connect(sig, cb)

func _process(_d: float) -> void:
	if _s:
		_s.call("run_callbacks")

func _log(t: String) -> void:
	print("[Steam] ", t)
	status_changed.emit(t)

## Steam'deki oyuncu adı (yoksa boş)
func player_name() -> String:
	return persona

# ── başarımlar ve istatistikler ────────────────────────────────────
func is_unlocked(id: String) -> bool:
	var prof := get_node_or_null("/root/Profile")
	return prof != null and bool(prof.data.get("achievements", {}).get(id, false))

func unlock(id: String) -> void:
	if not ACHIEVEMENTS.has(id) or is_unlocked(id):
		return
	var prof := get_node_or_null("/root/Profile")
	if prof:
		if not prof.data.has("achievements"):
			prof.data["achievements"] = {}
		prof.data.achievements[id] = true
		prof.save()
	if _s:
		_s.call("setAchievement", id)
		_s.call("storeStats")
	var lang := String(get_node("/root/I18n").lang) if has_node("/root/I18n") else "tr"
	var row: Array = ACHIEVEMENTS[id]
	achievement_unlocked.emit(id, row[1] if lang == "en" else row[0])

func unlocked_count() -> int:
	var n := 0
	for id in ACHIEVEMENTS:
		if is_unlocked(id):
			n += 1
	return n

func add_stat(stat: String, amount := 1) -> int:
	var prof := get_node_or_null("/root/Profile")
	var v := 0
	if prof:
		if not prof.data.has("stats"):
			prof.data["stats"] = {}
		v = int(prof.data.stats.get(stat, 0)) + amount
		prof.data.stats[stat] = v
		prof.save()
	if _s:
		_s.call("setStatInt", stat, v)
		_s.call("storeStats")
	return v

# ── zengin durum (arkadaş listesinde görünen) ──────────────────────
## key: lobby | trivia | conquest | wardrobe  (tools/steam/rich_presence.vdf)
func presence(key: String, detail := "") -> void:
	if not _s:
		return
	_s.call("setRichPresence", "steam_display", "#Status_" + key.capitalize())
	_s.call("setRichPresence", "detail", detail)
	if lobby_id != 0:
		_s.call("setRichPresence", "steam_player_group", str(lobby_id))
		_s.call("setRichPresence", "steam_player_group_size", str(_s.call("getNumLobbyMembers", lobby_id)))

# ── çevrimiçi: lobi + Remote Play Together ─────────────────────────
## Remote Play Together davet penceresi (Steam arayüzü). Yoksa arkadaş listesi.
func invite_remote_play() -> bool:
	if not _s:
		return false
	if _s.has_method("showRemotePlayTogetherUI"):
		_s.call("showRemotePlayTogetherUI")
		return true
	_s.call("activateGameOverlay", "Friends")
	return true

## Arkadaşlara açık lobi aç; açılınca davet penceresi çıkar
func host_lobby(max_members := 8) -> bool:
	if not _s:
		return false
	# 1 = LOBBY_TYPE_FRIENDS_ONLY
	_s.call("createLobby", 1, max_members)
	return true

func leave_lobby() -> void:
	if _s and lobby_id != 0:
		_s.call("leaveLobby", lobby_id)
	lobby_id = 0

func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		_log("lobi açılamadı (%d)" % result)
		return
	lobby_id = id
	_s.call("setLobbyJoinable", id, true)
	_s.call("setLobbyData", id, "name", persona + " · Trivia Arena")
	_s.call("setRichPresence", "connect", "+connect_lobby " + str(id))
	_s.call("activateGameOverlayInviteDialog", id)
	lobby_ready.emit(id)

func _on_lobby_joined(id: int, _perm: int, _locked: bool, response: int) -> void:
	if response == 1:
		lobby_id = id
		lobby_ready.emit(id)

## Arkadaşın davetine Steam'den "Katıl" dendi
func _on_join_requested(id: int, _friend: int) -> void:
	_s.call("joinLobby", id)
