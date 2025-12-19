extends CharacterBody2D

@export var max_hp := 40
var hp := 0

@export var gravity := 1600.0

@export var bullet_scene: PackedScene = preload("res://scenes/boss_bullet.tscn")
@export var bullet_speed := 520.0

@export var rock_scene: PackedScene = preload("res://scenes/falling_rock.tscn")

# ขอบสนาม
@export var arena_left_x := 120.0
@export var arena_right_x := 1800.0
@export var ground_y := 860.0

# roll movement
@export var roll_speed := 1200.0
@export var roll_stop_epsilon := 8.0
@export var roll_windup := 0.12

# muzzle fix (ถ้า Marker2D ไม่ได้เป็นลูกของ sprite ที่ flip)
@export var muzzle_offset_x := 120.0

@onready var anim: AnimatedSprite2D = $Anim
@onready var muzzle: Marker2D = $Muzzle
@onready var state_timer: Timer = $StateTimer
@export var healthbar_path: NodePath
@onready var healthbar = get_node_or_null(healthbar_path)

@onready var roll_hitbox: Area2D = $HitboxMelee

@export var windup_time := 1.5
@export var shoot3_release_time := 4.0
@export var heavy_release_time := 4.0

@export_category("Loot Settings")
@export var min_shards: int = 100   # บอสใหญ่ให้เยอะๆ เลย
@export var max_shards: int = 150
@export var shard_popup_scene: PackedScene # อย่าลืมลากไฟล์ใส่ใน Inspector นะ!

var player: Node2D = null

enum State { IDLE, SHOOT3, ROLL, BEAM_ROCK, HEAVY, DEAD }
var state: State = State.IDLE

var on_right := true
var _rolling_target_x := 0.0
var _busy := false

var _roll_hit_done := false
var _player_ref: Node2D = null
var _roll_started := false

var _pending_shots := 0
var _pending_mode := "" # "shoot3" หรือ "heavy"

# ---- SHOOT x3 ----
@onready var anim_player: AnimationPlayer = $AnimPlayer

var phase := 1

func _update_phase():
	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		print("=== BOSS PHASE 2 STARTED ===")

func _ready() -> void:
	randomize()
	add_to_group("enemy")

	hp = max_hp
	if healthbar and healthbar.has_method("init_health"):
		healthbar.init_health(max_hp)

	# เริ่มขวาสุด
	global_position = Vector2(arena_right_x, ground_y)
	on_right = true
	_apply_facing_and_muzzle()

	# roll hitbox setup
	if roll_hitbox:
		roll_hitbox.monitoring = false
		roll_hitbox.monitorable = false
		if not roll_hitbox.body_entered.is_connected(_on_roll_hitbox_body_entered):
			roll_hitbox.body_entered.connect(_on_roll_hitbox_body_entered)
	
	if anim and not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

	_find_player()
	_enter_idle()

func _process(_delta: float) -> void:
	if player == null:
		_find_player()

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0:
			velocity.y = 0

	# default: ไม่เดินใน IDLE / state อื่น (ยืนขอบอย่างเดียว)
	velocity.x = 0

	# ROLL: ขยับไปหา target แบบ “ขยับจริง” (ไม่วาร์ป)
	if state == State.ROLL and _roll_started:
		var dx := _rolling_target_x - global_position.x
		if absf(dx) <= roll_stop_epsilon:
			global_position.x = _rolling_target_x
			velocity.x = 0
			_finish_roll()
		else:
			velocity.x = signf(dx) * roll_speed

	move_and_slide()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

# ---------------- STATES ----------------

func _enter_idle() -> void:
	if state == State.DEAD:
		return

	state = State.IDLE
	_busy = false
	if anim: anim.play("idle")

	state_timer.stop()
	if state_timer.timeout.is_connected(_pick_next_state):
		state_timer.timeout.disconnect(_pick_next_state)
	state_timer.timeout.connect(_pick_next_state, CONNECT_ONE_SHOT)
	state_timer.start(1.2)

func _pick_next_state():
	if state == State.DEAD or _busy:
		return
	if phase == 1:
		match randi() % 3:
			0: _enter_shoot3()
			1: _enter_roll()
			2: _enter_heavy()
	else:
		match randi() % 4:
			0: _enter_shoot3()
			1: _enter_roll()
			2: _enter_heavy()
			3: _enter_target_rock()

func _enter_shoot3() -> void:
	if _busy or state == State.DEAD:
		return
	state = State.SHOOT3
	_start_shoot_sequence("shoot3", 3)

	await get_tree().create_timer(0.35, true, false, true).timeout
	if state != State.SHOOT3:
		_busy = false
		return

	for i in range(3):
		_fire_one_shot()
		await get_tree().create_timer(0.28, true, false, true).timeout
		if state != State.SHOOT3:
			_busy = false
			return

	await get_tree().create_timer(0.25, true, false, true).timeout
	_enter_idle()

func _fire_one_shot() -> void:
	if bullet_scene == null:
		return
	if player == null:
		_find_player()
		if player == null:
			return

	var b = bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)

	var from_pos := muzzle.global_position
	var to_pos := player.global_position + Vector2(0, -20)
	b.setup(from_pos, to_pos, self, bullet_speed)

# ---- HEAVY (1 นัด) ----
func _enter_heavy() -> void:
	if _busy or state == State.DEAD:
		return
	_busy = true
	state = State.HEAVY
	anim.play("heavy") # ให้ heavy เป็นท่าอ้าปากใหญ่/ชาร์จหนัก

	await get_tree().create_timer(0.8, true, false, true).timeout
	if state != State.HEAVY:
		_busy = false
		return

	if bullet_scene:
		if player == null:
			_find_player()
		if player != null:
			if anim: anim.play("heavy")
			var b = bullet_scene.instantiate()
			get_tree().current_scene.add_child(b)
			b.setup(muzzle.global_position, player.global_position + Vector2(0, -20), self, bullet_speed * 1.25)

	await get_tree().create_timer(0.45, true, false, true).timeout
	_enter_idle()

# ---- ROLL (สลับขอบชัวร์ + ไม่ติด player) ----
func _enter_roll() -> void:
	if _busy or state == State.DEAD:
		return
	_busy = true
	state = State.ROLL
	_roll_started = false
	if anim: anim.play("roll")

	_roll_hit_done = false

	# sync ฝั่งจาก "ตำแหน่งจริง" กัน on_right เพี้ยน
	var mid := (arena_left_x + arena_right_x) * 0.5
	on_right = global_position.x >= mid

	# ✅ ตั้ง target ทันที (สำคัญมาก กันเพี้ยน)
	_rolling_target_x = arena_left_x if on_right else arena_right_x

	# หา player ล่าสุด + ทำให้ทะลุ player (ไม่ชนกัน) แต่ยังชน world ได้
	if player == null:
		_find_player()
	_player_ref = player
	if _player_ref:
		add_collision_exception_with(_player_ref)

	# เปิด hitbox ทำดาเมจตอนกลิ้ง
	if roll_hitbox:
		roll_hitbox.monitoring = true
		roll_hitbox.monitorable = true

	# windup (แต่ยังไม่ขยับจนกว่าจะ _roll_started = true)
	await get_tree().create_timer(roll_windup, true, false, true).timeout
	if state != State.ROLL:
		_cleanup_roll_collision()
		_busy = false
		return

	_roll_started = true

func _finish_roll() -> void:
	_cleanup_roll_collision()

	# ตั้งฝั่งตาม "ปลายทางจริง" (ไม่ใช้ toggle แบบเดา)
	on_right = is_equal_approx(_rolling_target_x, arena_right_x)
	_apply_facing_and_muzzle()

	global_position.y = ground_y
	_busy = false
	_enter_idle()

# ---- BEAM -> ROCK PATTERN ----
func _enter_beam_rock() -> void:
	if _busy or state == State.DEAD:
		return
	_busy = true

	state = State.BEAM_ROCK
	if anim: anim.play("beam")

	await get_tree().create_timer(0.6, true, false, true).timeout
	if state != State.BEAM_ROCK:
		_busy = false
		return

	_spawn_rocks_pattern()

	await get_tree().create_timer(0.6, true, false, true).timeout
	_busy = false
	_enter_idle()

func _spawn_rocks_pattern() -> void:
	if rock_scene == null:
		return

	var cols := 6
	var width := arena_right_x - arena_left_x
	var step := width / cols
	var safe_col := randi() % cols

	for i in range(cols):
		if i == safe_col:
			continue
		var rock = rock_scene.instantiate()
		get_tree().current_scene.add_child(rock)

		var x := arena_left_x + step * i + step * 0.5
		rock.global_position = Vector2(x, ground_y - 900)
		rock.call("drop_to", ground_y)

# ---------------- DAMAGE ----------------
func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	if healthbar:
		healthbar.health = hp
	_update_phase()  # ✅ สำคัญมาก
	if hp <= 0:
		drop_loot()
		_die()

func _die() -> void:
	state = State.DEAD
	_busy = true
	if anim: anim.play("death")
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.6, true, false, true).timeout
	queue_free()

# ---------------- ROLL HITBOX ----------------
func _on_roll_hitbox_body_entered(body: Node) -> void:
	if state != State.ROLL:
		return
	if _roll_hit_done:
		return
	if body and body.is_in_group("player"):
		_roll_hit_done = true
		if body.has_method("take_damage"):
			body.take_damage(1)

func _cleanup_roll_collision() -> void:
	_roll_started = false

	# ปิด hitbox
	if roll_hitbox:
		roll_hitbox.monitoring = false
		roll_hitbox.monitorable = false

	# เอา exception ออก (กลับมาชน player ปกติ)
	if _player_ref and is_instance_valid(_player_ref):
		remove_collision_exception_with(_player_ref)
	_player_ref = null

func _apply_facing_and_muzzle() -> void:
	if anim:
		# sprite ปกติหันขวา
		# อยู่ขวา → ต้องหันซ้าย
		anim.flip_h = not on_right

	# muzzle: อยู่ด้านหน้าตามทิศ (ถ้า muzzle เป็นลูก root)
	if muzzle:
		# ถ้าบอสอยู่ขวา (หันซ้าย) -> muzzle ควรอยู่ซ้ายของตัว (-)
		# ถ้าบอสอยู่ซ้าย (หันขวา) -> muzzle อยู่ขวาของตัว (+)
		muzzle.position.x = -absf(muzzle_offset_x) if on_right else absf(muzzle_offset_x)

func fire_one_shot() -> void:
	_fire_one_shot()

func fire_heavy_shot() -> void:
	if bullet_scene == null:
		return
	if player == null:
		_find_player()
		if player == null:
			return
	if anim: anim.play("heavy")
	var b = bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.setup(muzzle.global_position, player.global_position + Vector2(0, -20), self, bullet_speed * 1.25)

func back_to_idle() -> void:
	_enter_idle()

func start_roll_move() -> void:
	_roll_started = true

func _on_shoot_release() -> void:
	# ✅ จะถูกเรียก “กลางแอนิเมชัน”
	_fire_one_shot()

func _start_shoot_sequence(mode: String, shots: int) -> void:
	_busy = true
	_pending_mode = mode
	_pending_shots = shots

	# เริ่มด้วยท่า shoot ก่อน แล้วค่อยเข้า hold
	anim.play("shoot")  # อ้าปาก/ชาร์จ

func _on_anim_finished() -> void:
	if state == State.DEAD:
		return

	# ยิง 3 นัด
	if state == State.SHOOT3 and anim.animation == "shoot":
		# เข้า hold แล้วค่อยยิง
		anim.play("hold")
		_fire_one_shot()
		_pending_shots -= 1

		# นัดถัดไป: กลับไป shoot แล้ววนใหม่
		if _pending_shots > 0:
			await get_tree().create_timer(0.28, true, false, true).timeout
			if state == State.SHOOT3:
				anim.play("shoot")
		else:
			await get_tree().create_timer(0.2, true, false, true).timeout
			_enter_idle()
		return

	# heavy 1 นัด
	if state == State.HEAVY and anim.animation == "heavy":
		anim.play("hold")
		fire_heavy_shot()
		await get_tree().create_timer(0.25, true, false, true).timeout
		_enter_idle()
		return

func _enter_target_rock():
	state = State.BEAM_ROCK
	anim.play("beam")

	if player == null:
		_find_player()
	if player == null:
		_enter_idle()
		return

	var target_x := player.global_position.x

	# telegraph delay
	await get_tree().create_timer(0.7).timeout

	var rock = rock_scene.instantiate()
	get_tree().current_scene.add_child(rock)
	rock.global_position = Vector2(target_x, ground_y - 900)
	rock.call("drop_to", ground_y)

	await get_tree().create_timer(0.4).timeout
	_enter_idle()

func drop_loot():
	var base_amount = randi_range(min_shards, max_shards)
	if base_amount <= 0: return

	# บวกเงินเข้า GameState
	GameState.add_shards(base_amount)
	
	# คำนวณยอดรวมโชว์ (Base + Bonus)
	var total_received = base_amount + GameState.shard_bonus_add
	
	# สร้าง Popup
	if shard_popup_scene:
		var popup = shard_popup_scene.instantiate()
		popup.global_position = global_position
		if popup.has_method("setup"):
			popup.setup(total_received)
		get_tree().current_scene.add_child(popup)
