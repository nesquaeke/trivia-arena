extends Node
## Hata raporlama.
##  · Motorun bütün hata/uyarılarını yakalar (OS.add_logger), son 200'ünü tutar.
##  · Oturum kilidi: açılışta user://reports/session.lock yazılır, düzgün
##    kapanışta silinir. Açılışta kilit duruyorsa önceki oturum çökmüştür:
##    önceki günlükten bir çökme raporu çıkarılır, oyuncuya haber verilir.
##  · Ayarlar → Hakkında: "Raporu kopyala" (panoya) ve "Rapor klasörü".
## Raporlar yalnız bu bilgisayarda durur; hiçbir yere kendiliğinden gönderilmez.

signal crash_detected(path: String)

const DIR := "user://reports/"
const LOCK := DIR + "session.lock"
const MAX := 200

var entries: Array[String] = []
var error_count := 0
var last_crash_report := ""
var _logger: Logger
var _session := ""

class Catcher extends Logger:
	var owner_node: Node
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["HATA", "UYARI", "BETİK", "SHADER"][clampi(error_type, 0, 3)]
		var msg := "%s %s: %s %s (%s:%d %s)" % [Time.get_time_string_from_system(), kind, code, rationale, file, line, function]
		for bt in script_backtraces:
			if bt and not bt.is_empty():
				msg += "\n" + bt.format(2)
				break
		if owner_node:
			owner_node.call_deferred("_add", msg, error_type != 1)
	func _log_message(_message: String, _error: bool) -> void:
		pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_session = Time.get_datetime_string_from_system().replace(":", "-")
	_logger = Catcher.new()
	(_logger as Catcher).owner_node = self
	OS.add_logger(_logger)
	# önceki oturum temiz kapanmadı mı?
	if FileAccess.file_exists(LOCK) and not _is_test():
		var prev := FileAccess.get_file_as_string(LOCK)
		last_crash_report = _write_crash_report(prev)
		call_deferred("emit_signal", "crash_detected", last_crash_report)
	if not _is_test():
		var f := FileAccess.open(LOCK, FileAccess.WRITE)
		if f:
			f.store_string(_session)
	get_tree().set_auto_accept_quit(true)

func _is_test() -> bool:
	return Array(OS.get_cmdline_args() + OS.get_cmdline_user_args()).any(func(a): return String(a).contains("tests.tscn") or String(a).contains("--shot"))

func _add(msg: String, is_error: bool) -> void:
	entries.append(msg)
	if entries.size() > MAX:
		entries.pop_front()
	if is_error:
		error_count += 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_clean_exit()

func _exit_tree() -> void:
	_clean_exit()

func _clean_exit() -> void:
	if FileAccess.file_exists(LOCK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK))
	if error_count > 0 and not _is_test():
		_save(DIR + "session-%s.txt" % _session, report_text())

## Sistem bilgisi + son hatalar: kopyalanıp geliştiriciye gönderilecek metin
func report_text() -> String:
	var lines := PackedStringArray()
	lines.append("Trivia Arena — hata raporu")
	lines.append("Sürüm: %s" % ProjectSettings.get_setting("application/config/version", "?"))
	lines.append("Godot: %s" % Engine.get_version_info().string)
	lines.append("Sistem: %s %s · %s" % [OS.get_name(), OS.get_version(), OS.get_processor_name()])
	lines.append("Ekran kartı: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	lines.append("Bellek: %d MB kullanımda" % int(OS.get_static_memory_usage() / 1048576))
	lines.append("Dil: %s · Zaman: %s" % [OS.get_locale(), Time.get_datetime_string_from_system()])
	lines.append("Hata sayısı (bu oturum): %d" % error_count)
	lines.append("")
	lines.append("— Son kayıtlar —")
	for e in entries.slice(maxi(0, entries.size() - 60)):
		lines.append(e)
	if last_crash_report != "":
		lines.append("")
		lines.append("— Önceki oturum çöktü: %s —" % last_crash_report)
	return "\n".join(lines)

func copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(report_text())

func open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(DIR))

func _save(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)

## Çökme raporu: Godot'nun bir önceki günlük dosyasının sonu (son 150 satır)
func _write_crash_report(prev_session: String) -> String:
	var logs := ProjectSettings.globalize_path("user://logs/")
	var newest := ""
	var d := DirAccess.open(logs)
	if d:
		var files := Array(d.get_files()).filter(func(n): return String(n).ends_with(".log") and n != "godot.log")
		files.sort()
		if not files.is_empty():
			newest = logs + String(files.back())
	var tail := ""
	if newest != "":
		var all := FileAccess.get_file_as_string(newest).split("\n")
		tail = "\n".join(all.slice(maxi(0, all.size() - 150)))
	var path := DIR + "crash-%s.txt" % prev_session
	_save(path, "Trivia Arena — çökme raporu\nOturum: %s\nSürüm: %s\nSistem: %s %s\n\n%s" % [
		prev_session, ProjectSettings.get_setting("application/config/version", "?"), OS.get_name(), OS.get_version(), tail])
	return ProjectSettings.globalize_path(path)
