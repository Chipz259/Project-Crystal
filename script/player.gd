extends CharacterBody2D
const MAX_ENERGY := 3

@export var energy_damage_by_stack := [1, 3, 6] 
# มี 1 energy = 1 dmg, มี 2 = 3 dmg, มี 3 = 6 dmg (ปรับเลขได้ตามใจ)

@export var perfect_block_window := 0.2  # เวลาบล็อกพอดีตอนกระสุนชน
@export var energy_projectile_scene : PackedScene = preload("res://scenes/energy.tscn")

@export var parry_hitstop := 0.06
@export var parry_shake_amount := 10.0
@export var parry_shake_duration := 0.12

var max_hp := 5
var hp := max_hp

var spawn_pos := Vector2.ZERO
var energy := 0

var blocking := false
var block_timer := 0.0
var _hitstop_lock := false

const SPEED = 300.0
const JUMP_VELOCITY = -400.0



func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _ready():
	add_to_group("player")
	hp = max_hp
	spawn_pos = global_position
	print("Player added to group 'player'", self)

func _process(delta):
	# ---------------------------
	# ระบบบล็อกแบบกดขณะ projectile ถึงตัว
	# ---------------------------
	if blocking:
		block_timer -= delta
	if block_timer <= 0:
		blocking = false

	if Input.is_action_just_pressed("block"):
		print("BLOCK pressed")
		blocking = true
		block_timer = perfect_block_window

	# ---------------------------
	# ยิง energy ออกตามเมาส์
	# ---------------------------
	if Input.is_action_just_pressed("shoot_energy") and energy > 0:
		print("SHOOT ENERGY, stack =", energy)
		shoot_energy()
		energy = 0


func on_projectile_hit(projectile):
	if blocking:
		energy = min(energy + 1, MAX_ENERGY)
		projectile.queue_free()
		# (ใส่ hitstop/shake/flash_parry ได้ตามเดิม)

		print("Blocked! Energy =", energy)

		# ✅ parry feedback
		flash_parry()
		get_tree().current_scene.screen_shake(5.0, 0.09)
		hitstop(0.1, 0.15)
	else:
		flash_damage()
		get_tree().current_scene.screen_shake(8.0, 0.12)
		hitstop(0.04, 0.05)

		take_damage(1)
		projectile.queue_free()

func shoot_energy():
	var stack := energy # จำไว้ก่อนรีเซ็ต
	var e = energy_projectile_scene.instantiate()
	e.global_position = global_position

	var mouse_pos = get_global_mouse_position()
	e.direction = (mouse_pos - global_position).normalized()

	# กำหนดดาเมจตามสแต็ก (1..3)
	var idx: int = clamp(stack - 1, 0, energy_damage_by_stack.size() - 1)
	e.damage = energy_damage_by_stack[idx]
	e.stack = stack # เผื่อเอาไปทำ VFX/ขนาด/เสียง

	get_tree().current_scene.add_child(e)

func flash_damage():
	var sprite := $AnimatedSprite2D  # แก้ path ให้ตรงกับของโปเต้
	var tween := create_tween()

	sprite.modulate = Color(1, 1, 1, 1)  # reset

	# กระพริบขาว → กลับเป็นปกติ 2 ครั้ง
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1).as_relative()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	print("Player died")
	respawn() # สตับไว้ก่อน เดี๋ยวค่อยผูกกับ Core/Checkpoint

func respawn() -> void:
	hp = max_hp
	global_position = spawn_pos
	velocity = Vector2.ZERO
	blocking = false
	block_timer = 0.0
	energy = 0

func flash_parry():
	var sprite := $AnimatedSprite2D
	var tween := create_tween()
	# กระพริบฟ้า/ขาวแว้บ ๆ (ทำแบบง่าย ๆ ด้วย modulate)
	tween.tween_property(sprite, "modulate", Color(0.6, 0.9, 1.2, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.08)

func hitstop(freeze_time: float, recover_time: float = 0.0) -> void:
	if _hitstop_lock:
		return
	_hitstop_lock = true

	var prev := Engine.time_scale
	Engine.time_scale = 0.0

	# ค้าง
	await get_tree().create_timer(freeze_time, true, false, true).timeout

	# คืนแบบเนียน (optional)
	if recover_time > 0.0:
		Engine.time_scale = prev
		await get_tree().create_timer(recover_time, true, false, true).timeout
	else:
		Engine.time_scale = prev

	_hitstop_lock = false

func parry_feedback():
	# 1) screen shake
	var scene := get_tree().current_scene
	if scene and scene.has_method("screen_shake"):
		scene.screen_shake(parry_shake_amount, parry_shake_duration)

	# 2) hitstop (freeze ทั้งเกม)
	hitstop(parry_hitstop)

	# 3) flash
	flash_parry()
