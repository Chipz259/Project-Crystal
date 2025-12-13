extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var b1: Button = $Panel/MarginContainer/VBoxContainer/Label/Option1
@onready var b2: Button = $Panel/MarginContainer/VBoxContainer/Label/Option2
@onready var b3: Button = $Panel/MarginContainer/VBoxContainer/Label/Option3
@onready var close_btn: Button = $Panel/MarginContainer/VBoxContainer/Label/Close


var _options: Array[Dictionary] = []

func _ready() -> void:
	panel.visible = false
	print("b1 =", b1)
	print("b2 =", b2)
	print("b3 =", b3)
	print("close_btn =", close_btn)

	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))
	close_btn.pressed.connect(close)

func open() -> void:
	_roll_options()
	_apply_text()
	panel.visible = true
	get_tree().paused = true

func close() -> void:
	panel.visible = false
	get_tree().paused = false

func _roll_options() -> void:
	# ตอนนี้ให้ “เห็นภาพสุ่ม 3 อัน” แต่มีผลจริงแค่ shard bonus
	var pool: Array[Dictionary] = [
		{"id":"shard_bonus", "text":"+1 Shard per kill (TEST)"},
		{"id":"parry_window", "text":"Parry Window +0.05s"},
		{"id":"placeholder_b", "text":"(??? ) Energy Cap +?? (Coming soon)"},
		{"id":"placeholder_c", "text":"(??? ) Heal +?? (Coming soon)"}
	]

	pool.shuffle()
	_options = [pool[0], pool[1], pool[2]]

func _apply_text() -> void:
	b1.text = _options[0]["text"]
	b2.text = _options[1]["text"]
	b3.text = _options[2]["text"]

func _pick(i: int) -> void:
	var id := str(_options[i].get("id", ""))
	if id == "shard_bonus":
		GameState.shard_bonus_add += 1
		print("Shard bonus now =", GameState.shard_bonus_add)
	if id == "parry_window":
		GameState.parry_window_bonus += 0.05
		print("Parry bonus =", GameState.parry_window_bonus)
	close()
