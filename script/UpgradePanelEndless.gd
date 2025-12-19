extends CanvasLayer
signal picked(id: String)

@onready var panel: Panel = $Panel
# เช็ค Path ของปุ่มให้ตรงกับใน Scene Tree ของนายนะ
@onready var b1: Button = $Panel/MarginContainer/VBoxContainer/Label/Option1
@onready var b2: Button = $Panel/MarginContainer/VBoxContainer/Label/Option2
@onready var b3: Button = $Panel/MarginContainer/VBoxContainer/Label/Option3

var _options: Array[Dictionary] = []

func _ready() -> void:
	panel.visible = false
	# ✅ ต้องเป็น ALWAYS เพื่อให้ทำงานตอนเกม Pause ได้
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))

func open() -> void:
	_roll_options()
	_apply_text()
	panel.visible = true
	get_tree().paused = true # หยุดเกมข้างหลัง

func _pick(i: int) -> void:
	var id := str(_options[i].get("id", ""))

	# --- Logic แจกของ ---
	if id == "shard_bonus": GameState.shard_bonus_add += 1
	if id == "parry_window": GameState.parry_window_bonus += 0.05
	if id == "heal_up": GameState.heal_bonus += 1
	# ------------------

	picked.emit(id)
	
	# ปิดหน้าต่าง + คืนค่าเกม
	panel.visible = false
	get_tree().paused = false
	
	# ✅ ไปด่านต่อไปทันที
	print("Upgrade Selected! Next Level...")
	queue_free() # ลบหน้านี้ทิ้ง
	GameManager.load_next_level() 

func _roll_options() -> void:
	var pool: Array[Dictionary] = [
		{"id":"shard_bonus", "text":"+1 Shard per kill"},
		{"id":"parry_window", "text":"Parry Window +0.05s"},
		{"id":"heal_up", "text":"Heal +1 (per heal)"},
	]
	pool.shuffle()
	_options = [pool[0], pool[1], pool[2]]

func _apply_text() -> void:
	if _options.size() >= 3:
		b1.text = _options[0]["text"]
		b2.text = _options[1]["text"]
		b3.text = _options[2]["text"]
