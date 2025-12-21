extends CanvasLayer

@onready var hp_bar = $healthbar_player
@onready var shard_label: Label = $ShardLabel
@onready var core_label: Label = $CoreLabel
@onready var level_label: Label = $LevelLabel

@onready var e1: TextureRect = $EnergyUI/Energy1
@onready var e2: TextureRect = $EnergyUI/Energy2
@onready var e3: TextureRect = $EnergyUI/Energy3

@onready var low_hp_vignette: ColorRect = $LowHPVignette
@export var low_hp_threshold := 0.35
@export var low_hp_max_alpha := 0.55
@export var low_hp_pulse_speed := 5.0

@export var energy_empty: Texture2D
@export var energy_fill: Texture2D

@export var energy_full_pulse_scale := 1.0050
@export var energy_full_pulse_speed := 6.0

var player: Node = null
var _last_energy := -1
var _last_hp := -999999

func _ready() -> void:
	print("HUD READY")
	# พยายามหา player ครั้งแรก
	player = get_tree().get_first_node_in_group("player")
	
	_sync_max_hp()
	
	shard_label.text = str(GameState.run_shards)
	if not GameState.run_shards_changed.is_connected(_on_shards_changed):
		GameState.run_shards_changed.connect(_on_shards_changed)

	core_label.text = str(GameState.cores)
	if not GameState.cores_changed.is_connected(_on_cores_changed):
		GameState.cores_changed.connect(_on_cores_changed)
	
	# เรียก update แต่ถ้า player ยังไม่มี มันจะ return ออกไปเอง (เพราะเราแก้ข้างล่างแล้ว)
	_update_all(true)

func _on_shards_changed(value: int) -> void:
	shard_label.text = str(value)

func _process(_delta: float) -> void:
	# --- ส่วนป้องกัน Error (Safety Check) ---
	if player == null:
		# พยายามหาใหม่ทุกเฟรมจนกว่าจะเจอ
		player = get_tree().get_first_node_in_group("player")
		
		# ถ้าเจอแล้ว ให้ตั้งค่าเริ่มต้นทันที
		if player:
			_sync_max_hp()
			_update_all(true)
		
		# ถ้ายังไม่เจอ ก็จบการทำงานเฟรมนี้ไปก่อน อย่าเพิ่งรันต่อ
		return
	# ------------------------------------
	
	_update_all(false)
	if level_label:
		level_label.text = "Cavern : " + str(GameManager.current_level)

func _sync_max_hp() -> void:
	if player == null:
		return
	var max_hp = player.get("max_hp")
	if max_hp != null:
		hp_bar.init_health(int(max_hp))

func _update_all(force: bool) -> void:
	# ✅✅ [แก้ตรงนี้] เพิ่มบรรทัดนี้เพื่อป้องกัน Crash !! ✅✅
	if player == null:
		return

	# ---- HP ----
	var hp = player.get("hp")
	if hp != null:
		var hp_i := int(hp)
		if force or hp_i != _last_hp:
			hp_bar.health = hp_i
			_last_hp = hp_i

	# ---- ENERGY (0..3) ----
	var en = player.get("energy")
	if en == null:
		return
	var en_i: int = clamp(int(en), 0, 3)

	if force or en_i != _last_energy:
		_set_energy_ui(en_i)
		_last_energy = en_i
	_update_low_hp_vignette()
	_update_energy_full_pulse(en_i)

func _set_energy_ui(count: int) -> void:
	var nodes := [e3, e2, e1]

	if _last_energy >= 0 and count > _last_energy:
		var idx := count - 1
		if idx >= 0 and idx < 3:
			_pop(nodes[idx])

	if _last_energy > 0 and count == 0:
		for n in nodes:
			if n:
				var t := create_tween()
				t.tween_property(n, "scale", Vector2(0.85, 0.85), 0.05)
				t.tween_property(n, "scale", Vector2.ONE, 0.08)

	for i in range(3):
		if nodes[i] == null:
			continue

		if energy_empty == null or energy_fill == null:
			nodes[i].visible = (i < count)
		else:
			nodes[i].texture = energy_fill if i < count else energy_empty
			nodes[i].visible = true

func _pop(node: CanvasItem) -> void:
	if node == null:
		return
	var t := create_tween()
	node.scale = Vector2.ONE
	t.tween_property(node, "scale", Vector2(1.50, 1.50), 0.06)
	t.tween_property(node, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_low_hp_vignette() -> void:
	if low_hp_vignette == null or player == null:
		return

	var max_hp_var = player.get("max_hp")
	var hp_var = player.get("hp")
	if max_hp_var == null or hp_var == null:
		return

	var max_hp := float(max_hp_var)
	var hp := float(hp_var)
	if max_hp <= 0.0:
		low_hp_vignette.modulate.a = 0.0
		return

	var ratio := hp / max_hp

	if ratio >= low_hp_threshold:
		low_hp_vignette.modulate.a = 0.0
		return

	var t: float = clamp((low_hp_threshold - ratio) / low_hp_threshold, 0.0, 1.0)
	var pulse := (sin(Time.get_ticks_msec() / 1000.0 * low_hp_pulse_speed) * 0.5 + 0.5)
	var alpha: float = low_hp_max_alpha * t * (0.75 + 0.25 * pulse)

	low_hp_vignette.modulate.a = alpha

func _update_energy_full_pulse(en_i: int) -> void:
	var ui := get_node_or_null("EnergyUI")
	if ui == null:
		return

	if en_i >= 3:
		var pulse := (sin(Time.get_ticks_msec() / 1000.0 * energy_full_pulse_speed) * 0.5 + 0.5)
		var s: float = lerp(1.0, energy_full_pulse_scale, pulse)
		ui.scale = Vector2(s, s)
	else:
		ui.scale = Vector2.ONE

func _on_cores_changed(value: int) -> void:
	core_label.text = str(value)
