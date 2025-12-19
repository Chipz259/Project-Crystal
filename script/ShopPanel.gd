extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var box: VBoxContainer = $Panel/VBoxContainer

@onready var title_label: Label = $Panel/VBoxContainer/LabelTitle
@onready var b1: Button = $Panel/VBoxContainer/Option1
@onready var b2: Button = $Panel/VBoxContainer/Option2
@onready var b3: Button = $Panel/VBoxContainer/Option3
@onready var reset_btn: Button = $Panel/VBoxContainer/Reset
@onready var close_btn: Button = $Panel/VBoxContainer/Close
@onready var status: Label = $Panel/VBoxContainer/Status

@export var reset_base_cost := 3
@export var reset_cost_step := 2   # รีครั้งถัดไปแพงขึ้น +2
var _reset_count := 0
@export var shard_bonus_price := 6
@export var parry_window_price := 10
@export var core_price := 50
@export var core_weight := 1

var _options: Array[Dictionary] = []
var _bought_slots := [false, false, false]

func _ready() -> void:
	print("[ShopPanel] READY")
	# กัน node หาย
	if not panel or not box or not b1 or not b2 or not b3 or not reset_btn or not close_btn or not status:
		push_error("[ShopPanel] Missing UI nodes. Check node names/paths.")
		return

	# ให้ UI ทำงานตอน paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	b1.process_mode = Node.PROCESS_MODE_ALWAYS
	b2.process_mode = Node.PROCESS_MODE_ALWAYS
	b3.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	panel.visible = false
	status.text = ""
	title_label.text = "SHOP"

	# connect ปุ่ม
	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))
	reset_btn.pressed.connect(_reset_shop)
	close_btn.pressed.connect(close)

	print("[ShopPanel] connected buttons OK")

func open() -> void:
	panel.visible = true
	get_tree().paused = true
	status.text = ""
	if _options.is_empty():
		_reset_count = 0   # ✅ reset ราคาเมื่อเปิดร้านครั้งแรกของรอบนี้
		_roll_options()
	_apply_text_and_state()

func close() -> void:
	print("[ShopPanel] CLOSE")
	panel.visible = false
	get_tree().paused = false

func _roll_options() -> void:
	_bought_slots = [false, false, false]

	var pool: Array[Dictionary] = [
		{"id":"shard_bonus", "text":"+1 Shard per kill", "cost": shard_bonus_price, "weight": 6},
		{"id":"parry_window", "text":"Parry Window +0.05s", "cost": parry_window_price, "weight": 6},
		{"id":"placeholder_a", "text":"(Coming soon) Energy VFX+", "cost": 4, "weight": 4},
		{"id":"placeholder_b", "text":"(Coming soon) Heal +1", "cost": 7, "weight": 4},
		{"id":"core", "text":"Buy 1 Core (RARE)", "cost": core_price, "weight": core_weight},
	]

	_options = _pick_weighted_unique(pool, 3)
	print("[ShopPanel] rolled options =", _options)


func _apply_text_and_state() -> void:
	_set_button_from_option(b1, _options[0], 0)
	_set_button_from_option(b2, _options[1], 1)
	_set_button_from_option(b3, _options[2], 2)

	var cost := _current_reset_cost()
	reset_btn.text = "Reset shop (-%d shards)" % [cost]
	reset_btn.disabled = GameState.run_shards < cost

func _set_button_from_option(btn: Button, opt: Dictionary, slot: int) -> void:
	var bought := bool(_bought_slots[slot])

	if bought:
		btn.text = "SOLD"
		btn.disabled = true
		return

	btn.text = "%s (%d shards)" % [str(opt.get("text","???")), int(opt.get("cost", 0))]
	btn.disabled = false


func _pick(i: int) -> void:
	print("[ShopPanel] PICK", i, " shards=", GameState.run_shards)

	if _bought_slots[i]:
		status.text = "This item is already sold."
		return

	var opt := _options[i]
	var cost := int(opt.get("cost", 0))
	if GameState.run_shards < cost:
		status.text = "Not enough shards."
		_apply_text_and_state()
		return

	# จ่าย
	GameState.run_shards -= cost
	GameState.run_shards_changed.emit(GameState.run_shards)

	# ให้ของ
	match str(opt.get("id","")):
		"shard_bonus":
			GameState.shard_bonus_add += 1
			status.text = "Purchased: shard bonus!"
		"parry_window":
			GameState.parry_window_bonus += 0.05
			status.text = "Purchased: parry window!"
		"core":
			GameState.cores += 1
			GameState.cores_changed.emit(GameState.cores)
			status.text = "Purchased: 1 core!"
		_:
			status.text = "Purchased! (placeholder)"

	# ✅ ล็อกแค่ช่องนี้
	_bought_slots[i] = true
	_apply_text_and_state()

func _reset_shop() -> void:
	var cost := _current_reset_cost()
	print("[ShopPanel] RESET cost=", cost, " shards=", GameState.run_shards)

	if GameState.run_shards < cost:
		status.text = "Not enough shards to reset."
		_apply_text_and_state()
		return

	GameState.run_shards -= cost
	GameState.run_shards_changed.emit(GameState.run_shards)

	_reset_count += 1            # ✅ แพงขึ้นเรื่อย ๆ
	_roll_options()
	status.text = "Shop refreshed!"
	_apply_text_and_state()

func _pick_weighted_unique(pool: Array[Dictionary], count: int) -> Array[Dictionary]:
	var remaining := pool.duplicate(true)
	var result: Array[Dictionary] = []

	while result.size() < count and remaining.size() > 0:
		var total := 0
		for it in remaining:
			total += int(it.get("weight", 1))

		var r : float = randi() % max(1, total)
		var acc := 0
		var chosen_index := 0

		for idx in range(remaining.size()):
			acc += int(remaining[idx].get("weight", 1))
			if r < acc:
				chosen_index = idx
				break

		result.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)

	return result

func _current_reset_cost() -> int:
	# ถ้าอยากให้ +2 3-5-7-9-11-13-15
	return reset_base_cost + _reset_count * reset_cost_step
	# ถ้าอยากให้ x1.6 3-5-8-13-21-34
	# return int(round(reset_base_cost * pow(1.6, _reset_count)))
