extends CharacterBody2D
const MAX_ENERGY := 3

@export var block_cooldown := 0.6   # คูลดาวน์หลังบล็อก (ปรับได้)
var block_cd_timer := 0.0

@export var energy_damage_by_stack := [1, 3, 6] 
# มี 1 energy = 1 dmg, มี 2 = 3 dmg, มี 3 = 6 dmg (ปรับเลขได้ตามใจ)

@export var perfect_block_window := 0.20  # เวลาบล็อกพอดีตอนกระสุนชน
@export var energy_projectile_scene : PackedScene = preload("res://scenes/energy.tscn")

@export var parry_hitstop := 0.06
@export var parry_shake_amount := 10.0
@export var parry_shake_duration := 0.12
var _parry_success_this_block := false
var _parry_consumed := false

@export var base_heal_amount := 1

var max_hp := 5
var hp := max_hp
var invincible := false

var spawn_pos := Vector2.ZERO
var energy := 0

var blocking := false
var block_timer := 0.0
var _hitstop_lock := false

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var anim_state : AnimState = AnimState.IDLE
@onready var anim := $AnimatedSprite2D

enum AnimState {
	IDLE,
	RUN,
	JUMP,
	FALL,
	BLOCK,
	SHOOT,
	HIT,
	DEAD
}

func _physics_process(delta: float) -> void:
	# ✅ Freeze ระหว่าง block window
	if blocking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# ----- ของเดิม -----
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func update_anim_fsm() -> void:
	var new_state := anim_state

	# ---- Highest priority (override everything visually) ----
	if hp <= 0:
		new_state = AnimState.DEAD
	elif blocking:
		new_state = AnimState.BLOCK   # works mid-air
	elif not is_on_floor():
		if velocity.y < 0:
			new_state = AnimState.JUMP
		else:
			new_state = AnimState.FALL
	else:
		if abs(velocity.x) > 5:
			new_state = AnimState.RUN
		else:
			new_state = AnimState.IDLE

	# ---- Apply animation only when state changes ----
	if new_state != anim_state:
		anim_state = new_state
		play_anim_for_state(anim_state)
		
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0

func play_anim_for_state(state: AnimState) -> void:
	match state:
		AnimState.IDLE:
			print("idle")
			anim.play("idle")
		AnimState.RUN:
			print("run")
			anim.play("run")
		AnimState.JUMP:
			anim.play("jump")
		AnimState.FALL:
			anim.play("fall")
		AnimState.BLOCK:
			anim.play("block")
		AnimState.SHOOT:
			anim.play("shoot")
		AnimState.HIT:
			anim.play("hit")
		AnimState.DEAD:
			anim.play("dead")


func _ready():
	add_to_group("player")
	hp = max_hp
	spawn_pos = global_position
	print("Player added to group 'player'", self)

	# ✅ restore state จาก GameState ถ้ามี
	var saved := GameState.consume_player_state()
	var sh := int(saved.get("hp", -1))
	var se := int(saved.get("energy", -1))

	if sh >= 0:
		hp = clamp(sh, 0, max_hp)
	if se >= 0:
		energy = clamp(se, 0, MAX_ENERGY)

func _process(delta):
	# --- ลด cooldown ---
	if block_cd_timer > 0.0:
		block_cd_timer -= delta

	# --- ลด block window ---
	if blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			blocking = false
			# ✅ ถ้า parry สำเร็จในบล็อกนี้ -> ไม่ติดคูลดาวน์
			if _parry_success_this_block:
				block_cd_timer = 0.0
				print("CHAIN PARRY! No cooldown")
			else:
				block_cd_timer = block_cooldown
				print("BLOCK window ended -> cooldown started:", snapped(block_cd_timer, 0.01))

	# --- กด block ---
	# --- กด block ---
	if Input.is_action_just_pressed("block"):
		if blocking:
			print("BLOCK already active")
		elif block_cd_timer > 0.0:
			print("BLOCK on cooldown:", snapped(block_cd_timer, 0.01))
		else:
			print("BLOCK pressed")

			# ✅ เริ่ม parry ใหม่
			blocking = true
			_parry_consumed = false   # <<<<<< ใส่ตรงนี้
			block_timer = perfect_block_window + GameState.parry_window_bonus

	# --- ยิง energy ตามเดิม ---
	if Input.is_action_just_pressed("shoot_energy") and energy > 0:
		print("SHOOT ENERGY, stack =", energy)
		shoot_energy()
		energy = 0

	# --- heal ด้วย energy 1 ---
	if Input.is_action_just_pressed("heal"):
		try_heal()
		
	update_anim_fsm()

func on_projectile_hit(projectile):
	# 1) parry สำเร็จ
	if blocking and not _parry_consumed:
		_parry_consumed = true

		energy = min(energy + 1, MAX_ENERGY)
		projectile.queue_free()

		flash_parry()
		get_tree().current_scene.screen_shake(5.0, 0.09)
		hitstop(0.1, 0.15)

		# จบ parry ทันที
		blocking = false
		block_timer = 0.0
		block_cd_timer = 0.0
		print("Parry consumed -> press again for next projectile")
		return

	# ✅ invincible: โดนแล้วให้หายไปเฉย ๆ (กันบัคช่วง transition)
	if invincible:
		projectile.queue_free()
		return

	# 2) ถือบล็อกอยู่แต่ parry ถูกใช้ไปแล้ว -> ปกติจะโดนดาเมจ
	if blocking and _parry_consumed:
		flash_damage()
		get_tree().current_scene.screen_shake(8.0, 0.12)
		hitstop(0.04, 0.05)
		take_damage(1)
		projectile.queue_free()
		return

	# 3) ไม่ได้บล็อก -> โดนดาเมจ
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
	if invincible:
		print("Damage ignored: invincible")
		return

	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	print("Player died")

	if GameState.cores > 0:
		GameState.cores -= 1
		GameState.cores_changed.emit(GameState.cores) # 👈 ใส่ตรงนี้
		respawn()
	else:
		get_tree().quit()

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

func try_heal() -> void:
	if energy < 1:
		print("HEAL failed: no energy")
		return
	if hp >= max_hp:
		print("HEAL blocked: hp full")
		return

	energy -= 1

	var heal_amount := base_heal_amount + GameState.heal_bonus
	hp = min(hp + heal_amount, max_hp)

	print("HEAL +", heal_amount, " hp=", hp, "/", max_hp, " energy=", energy)

	# optional feedback
	flash_parry() # ถ้าอยากแยกสีเขียว เดี๋ยวแชททำให้
