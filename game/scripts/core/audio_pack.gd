class_name AudioPack
extends RefCounted
## Profesyonel ses paketi: oyunun ürettiği her sesin yerine aynı adlı bir dosya konabilir.
## Arama sırası (ilk bulunan kazanır):
##   1) user://audio/<tür>/<ad>.ogg|.wav|.mp3   oyunu yeniden derlemeden: kayıt klasöründeki
##      "audio" klasörüne dosyayı bırak, oyunu yeniden başlat
##   2) res://assets/audio_pro/<tür>/<ad>.ogg|.wav|.mp3   projeye eklenip dışa aktarılanlar
## Türler: sfx, music, mayhem, voice/tr, voice/en, voice/pl, voice/fr, voice/es
## Ad listesi: game/assets/audio_pro/README.md

const EXTS := ["ogg", "wav", "mp3"]
static var _cache := {}

static func find(kind: String, name: String) -> AudioStream:
	var key := kind + "/" + name
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for ext in EXTS:
		var up := "user://audio/%s/%s.%s" % [kind, name, ext]
		if FileAccess.file_exists(up):
			s = _load_file(up, ext)
			if s:
				break
	if s == null:
		for ext in EXTS:
			var rp := "res://assets/audio_pro/%s/%s.%s" % [kind, name, ext]
			if ResourceLoader.exists(rp):
				s = load(rp)
				break
	_cache[key] = s
	return s

static func _load_file(path: String, ext: String) -> AudioStream:
	var full := ProjectSettings.globalize_path(path)
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(full)
		"mp3":
			return AudioStreamMP3.load_from_file(full)
		"wav":
			return AudioStreamWAV.load_from_file(full)
	return null

## Kullanıcı ses klasörünü oluştur (Ayarlar > Hakkında'dan açılır) ve yolunu döndür
static func user_dir() -> String:
	for k in ["sfx", "music", "mayhem", "voice/tr", "voice/en", "voice/pl", "voice/fr", "voice/es"]:
		DirAccess.make_dir_recursive_absolute("user://audio/" + k)
	return ProjectSettings.globalize_path("user://audio")

static func clear_cache() -> void:
	_cache.clear()
