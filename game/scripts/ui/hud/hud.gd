class_name Hud
extends Control
## Oyun içi arayüz. Oyun modları yalnızca buradaki hud_* fonksiyonlarını
## çağırır (ui_root.gd bunları buraya aktarır).
##
##   sol üst   RoundBadge   perde + tur adı
##   sol       ScoreRail    oyuncu kartları
##   sağ üst   RingTimer    sayaç
##   üst orta  QuestionCard soru + şıklar
##   alt orta  Callout      duyurular / TugMeter halat
##   tam ekran RoundCard, RewardPicker, StandingsBoard, ResultScreen

signal reward_clicked(step: int, index: int)
signal answer_clicked(index: int)
signal again_pressed
signal back_pressed

var badge: RoundBadge
var rail: ScoreRail
var timer: RingTimer
var question: QuestionCard
var callout: Callout
var tug: TugMeter
var round_card: RoundCard
var reward: RewardPicker
var standings: StandingsBoard
var result: ResultScreen
var estimate: EstimatePanel
var _tug_open := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge = RoundBadge.new()
	badge.position = Vector2(30, 26)
	add_child(badge)
	rail = ScoreRail.new()
	rail.position = Vector2(30, 150)
	rail.size = Vector2(340, 800)
	add_child(rail)
	timer = RingTimer.new()
	timer.position = Vector2(1920 - 156 - 34, 30)
	add_child(timer)
	question = QuestionCard.new()
	question.position = Vector2((1920 - QuestionCard.W) * 0.5, 22)
	question.answer_clicked.connect(func(i): answer_clicked.emit(i))
	add_child(question)
	estimate = EstimatePanel.new()
	estimate.position = Vector2((1920 - EstimatePanel.W) * 0.5, 22)
	add_child(estimate)
	callout = Callout.new()
	callout.position = Vector2((1920 - 1400) * 0.5, 930)
	add_child(callout)
	tug = TugMeter.new()
	tug.position = Vector2((1920 - TugMeter.W) * 0.5, 22)
	add_child(tug)
	standings = StandingsBoard.new()
	add_child(standings)
	reward = RewardPicker.new()
	reward.clicked.connect(func(s, i): reward_clicked.emit(s, i))
	add_child(reward)
	round_card = RoundCard.new()
	add_child(round_card)
	result = ResultScreen.new()
	result.again.connect(func(): again_pressed.emit())
	result.back.connect(func(): back_pressed.emit())
	add_child(result)
	visible = false

func reset() -> void:
	rail.clear()
	for c in [rail, badge]:
		Fx.cancel_fade(c)
		c.visible = true
		c.modulate.a = 1.0
	badge.set_round("", "")
	question.visible = false
	estimate.visible = false
	tug.visible = false
	_tug_open = false
	round_card.visible = false
	reward.visible = false
	standings.visible = false
	result.visible = false
	callout.say("")
	timer.set_time(0.0, 1.0)

# ── modların çağırdığı API ─────────────────────────────────────────
func hud_message(text: String, accent := Pal.GOLD, sub := "") -> void:
	callout.say(text, accent, sub)

func hud_top(text: String, sub := "") -> void:
	badge.set_round(sub, text)

func hud_scores(rows: Array) -> void:
	rail.update_rows(rows)

func hud_round(r: int, title: String) -> void:
	badge.set_round(Pal.t("round.kicker") + " " + Pal.roman(r), title)

func hud_round_card(r: int, title: String, desc: String, chips: Array) -> void:
	question.hide_card()
	hud_round(r, title)
	round_card.show_card(r, title, desc, chips)

func hud_round_card_hide() -> void:
	round_card.hide_card()

func hud_tug(names: Array, cols: Array, pulls: Array, left: float, total: float) -> void:
	if not _tug_open:
		_tug_open = true
		tug.open(names, cols, Pal.t("tug.title"), Pal.t("tug.sub"))
		callout.say("")
	tug.update_state(pulls, left, total)
	timer.set_time(left, total)

func hud_tug_winner(i: int) -> void:
	tug.set_winner(i)

func hud_tug_hide() -> void:
	_tug_open = false
	tug.close()

func hud_question(label: String, prompt: String, options: Array, cat_name: String, cat_color: Color, total: float, stake: int, pips := Vector2i(0, 0)) -> void:
	question.show_question(label, prompt, options, cat_name, cat_color, stake, pips)
	timer.set_time(total, total)

func hud_question_hide() -> void:
	question.hide_card()

func hud_timer(left: float, total: float) -> void:
	timer.set_time(left, total)
	if reward.visible:
		reward.set_time(left, total)

func hud_reveal(correct: int) -> void:
	question.show_reveal(correct)

func hud_reward_open(p_name: String, color: Color, targets: Array, actions: Array) -> void:
	reward.open(p_name, color, targets, actions)

func hud_reward_select(step: int, idx: int) -> void:
	reward.select(step, idx)

func hud_reward_close() -> void:
	reward.close()

func hud_standings(rows: Array, round_no: int) -> void:
	question.hide_card()
	standings.open(rows, round_no)

func hud_standings_hide() -> void:
	standings.close()

# ── Conquest ────────────────────────────────────────────────────────
func hud_estimate_open(kicker: String, q: String, unit: String, dials: Array, year: bool) -> void:
	question.hide_card()
	estimate.open(kicker, q, unit, dials, year)

func hud_estimate_dial(i: int, value: int, cursor: int, locked: bool) -> void:
	estimate.update_dial(i, value, cursor, locked)

func hud_estimate_reveal(answer: String, ranked: Array) -> void:
	estimate.reveal(answer, ranked)

func hud_estimate_close() -> void:
	estimate.close()

func hud_duel_marks(marks: Array, clickable: bool) -> void:
	question.marks = marks
	question.clickable = clickable

func show_result(title: String, names: Array, rows: Array = []) -> void:
	question.hide_card()
	tug.visible = false
	callout.say("")
	timer.set_time(0.0, 1.0)
	Fx.fade(rail, 0.0, 0.4)
	Fx.fade(badge, 0.0, 0.4)
	result.open(title, names, rows)

func hide_result() -> void:
	result.close()
