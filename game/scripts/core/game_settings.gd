class_name GameSettings
extends RefCounted
## Ayarlar ekranındaki seçeneklerin oyuna uygulanması (Profile'da saklanır).
##   master_vol, music_vol, sfx_vol   0–1
##   fullscreen                       bool
##   quality                          "low" | "medium" | "high"
##   shake                            bool (kamera sarsıntısı)
##   vsync                            bool
##   window                           "windowed" | "borderless" | "fullscreen"
##   fps                              0 (sınırsız) | 30 | 60 | 120
##   grain, narrator, hints           bool
##   voice_vol                        0–1

const QUALITY := ["low", "medium", "high"]

static func apply_all(tree: SceneTree) -> void:
	apply_window()
	apply_quality(tree)
	apply_audio(tree)
	apply_grain(tree)

static func _prof() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and ml.root.has_node("Profile"):
		return ml.root.get_node("Profile")
	return null

static func get_v(key: String, fallback):
	var p := _prof()
	return p.setting(key, fallback) if p else fallback

static func apply_audio(tree: SceneTree) -> void:
	var m := tree.root.get_node_or_null("Music")
	if m:
		m.apply_volumes()

## "windowed" | "borderless" | "fullscreen" (eski "fullscreen" bool ayarını da okur)
static func window_mode() -> String:
	var w := String(get_v("window", ""))
	if w == "":
		w = "fullscreen" if bool(get_v("fullscreen", false)) else "windowed"
	return w

static func apply_window() -> void:
	Engine.max_fps = int(get_v("fps", 0))
	if DisplayServer.get_name() == "headless":
		return
	var w := window_mode()
	var want := DisplayServer.WINDOW_MODE_WINDOWED
	if w == "fullscreen":
		want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	elif w == "borderless":
		want = DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_v("vsync", true)) else DisplayServer.VSYNC_DISABLED)

## Film greni (eski sinema dokusu) açık/kapalı
static func apply_grain(tree: SceneTree) -> void:
	var ui := tree.root.find_child("UI", true, false)
	if ui and "grain" in ui and ui.grain:
		ui.grain.visible = bool(get_v("grain", true))

## Kalite: düşükte hacimsel sis, SSAO ve MSAA kapanır, 3D çözünürlük %75'e iner
static func apply_quality(tree: SceneTree) -> void:
	var q := String(get_v("quality", "high"))
	var vp := tree.root.get_viewport()
	match q:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.75
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"medium":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var stage := tree.root.find_child("Stage", true, false)
	if stage and "env" in stage and stage.env:
		var env: Environment = stage.env
		env.volumetric_fog_enabled = q != "low"
		env.ssao_enabled = q == "high"
		env.glow_enabled = true
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q == "low" else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q == "low" else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)

static func shake_on() -> bool:
	return bool(get_v("shake", true))
