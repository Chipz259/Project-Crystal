extends Node2D

@export var player_scene: PackedScene
@export var boss_scene: PackedScene
@export var hud_scene: PackedScene

@export var player_spawn: Vector2 = Vector2(200, 500)
@export var boss_spawn: Vector2 = Vector2(1100, 500)

var player: Node2D
var boss: Node2D
var hud: Node

func _ready() -> void:
	# --- Spawn order ที่ชัวร์: Player -> Boss -> HUD ---
	_spawn_player()
	_spawn_boss()

	# รอ 1 เฟรมให้ Player ready/group พร้อม แล้วค่อยสร้าง HUD
	await get_tree().process_frame
	_spawn_hud()

	# กัน low hp vignette ค้าง (เผื่อ HUD มีค่า alpha ติดจาก editor)
	_force_hide_low_hp_vignette()

	print("[Map_Boss1] ready OK player=", player, " boss=", boss, " hud=", hud)

func _spawn_player() -> void:
	if player_scene == null:
		push_error("[Map_Boss1] player_scene not set!")
		return
	player = player_scene.instantiate() as Node2D
	add_child(player)
	player.global_position = player_spawn

	# safety: ถ้า player ยังไม่ได้ add_to_group ใน _ready() (กรณีสคริปต์เปลี่ยน)
	if not player.is_in_group("player"):
		player.add_to_group("player")

func _spawn_boss() -> void:
	if boss_scene == null:
		push_error("[Map_Boss1] boss_scene not set!")
		return
	boss = boss_scene.instantiate() as Node2D
	add_child(boss)
	boss.global_position = boss_spawn

func _spawn_hud() -> void:
	if hud_scene == null:
		push_error("[Map_Boss1] hud_scene not set!")
		return
	hud = hud_scene.instantiate()
	add_child(hud)

	# ให้ HUD ทำงานตอน pause ได้ (ร้าน/อัปเกรดของนายใช้ pause บ่อย)
	if hud is Node:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS

	# ถ้า HUD มีเมธอด set_player ให้ยัด reference เข้าไป (ถ้าจะทำเพิ่มในอนาคต)
	if hud.has_method("set_player"):
		hud.call("set_player", player)

func _force_hide_low_hp_vignette() -> void:
	# กันจอแดงค้าง: หา node LowHPVignette ใน HUD แล้วบังคับ alpha=0
	if hud == null:
		return

	var v := hud.get_node_or_null("LowHPVignette")
	if v and v is ColorRect:
		v.modulate.a = 0.0

func screen_shake(amount := 8.0, duration := 0.2) -> void:
	# ถ้า map boss ไม่มี Camera2D ก็ปล่อยผ่าน (ไม่พัง)
	var cam := get_node_or_null("Camera2D")
	if cam == null:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cam, "offset", Vector2(randf()*amount, randf()*amount), duration / 2)
	tween.tween_property(cam, "offset", Vector2.ZERO, duration / 2)
