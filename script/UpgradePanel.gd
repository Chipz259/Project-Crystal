extends CanvasLayer
signal picked(id: String)

@onready var panel: Panel = $Panel
@onready var b1: Button = $Panel/MarginContainer/VBoxContainer/Label/Option1
@onready var b2: Button = $Panel/MarginContainer/VBoxContainer/Label/Option2
@onready var b3: Button = $Panel/MarginContainer/VBoxContainer/Label/Option3
@onready var close_btn: Button = $Panel/MarginContainer/VBoxContainer/Label/Close

var _options: Array[Dictionary] = []
var _pause_on_open := false

func _ready() -> void:
	panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # ✅ ทำงานแม้ paused
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))
	close_btn.pressed.connect(close)

func open(pause_game: bool = true) -> void:
	_pause_on_open = pause_game
	_roll_options()
	_apply_text()
	panel.visible = true
	if _pause_on_open:
		get_tree().paused = true

func close() -> void:
	panel.visible = false
	if _pause_on_open:
		get_tree().paused = false

func _pick(i: int) -> void:
	var id := str(_options[i].get("id", ""))

	if id == "shard_bonus":
		GameState.shard_bonus_add += 1
	if id == "parry_window":
		GameState.parry_window_bonus += 0.05
	if id == "heal_up":
		GameState.heal_bonus += 1
	if id == "atk_up":
		GameState.atk_up += 1

	picked.emit(id)     # ✅ บอก Transition ว่าเลือกแล้ว
	close()

func _roll_options() -> void:
	# ตอนนี้ให้ “เห็นภาพสุ่ม 3 อัน” แต่มีผลจริงแค่ shard bonus
	var pool: Array[Dictionary] = [
		{"id":"shard_bonus", "text":"+10 Shard per kill"},
		{"id":"parry_window", "text":"Parry Window +0.05s"},
		{"id":"heal_up", "text":"Heal +1 (per heal)"},
		{"id":"atk_up", "text":"Attack Damage +1"},
	]

	pool.shuffle()
	_options = [pool[0], pool[1], pool[2]]

func _apply_text() -> void:
	b1.text = _options[0]["text"]
	b2.text = _options[1]["text"]
	b3.text = _options[2]["text"]
