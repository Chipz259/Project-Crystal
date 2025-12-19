# boss2.gd (Final Multi-Hitbox Version)
extends CharacterBody2D

# -------------------- 1. CONFIG (ตั้งค่า) --------------------
@export_group("Stats")
@export var max_hp: int = 60
@export var hp: int = 60
@export var gravity: float = 1600.0

@export_group("Movement")
@export var move_speed: float = 120.0
@export var accel: float = 900.0
@export var chase_radius: float = 900.0
@export var wake_radius: float = 240.0

@export_group("Combat - AI")
@export var decision_cooldown: float = 0.5
@export var dist_melee: float = 100.0   # ถ้าระยะน้อยกว่านี้ -> ฟัน (Melee)
@export var dist_range: float = 300.0   # ถ้าระยะน้อยกว่านี้ -> ฟันไกล (Range)

@export_group("Combat - Damage & Frames")
# MELEE (ฟันใกล้)
@export var dmg_melee: int = 1
@export var frame_melee_start: int = 8
@export var frame_melee_end: int = 12

# RANGE (ฟันไกล)
@export var dmg_range: int = 1
@export var frame_range_start: int = 5
@export var frame_range_end: int = 9

# SUPER (ท่าไม้ตาย)
@export var dmg_super: int = 2
@export var frame_super_start: int = 10
@export var frame_super_end: int = 15

# -------------------- 2. NODES (ดึงโหนดมาใช้) --------------------
@onready var anim: AnimatedSprite2D = $Anim
@onready var state_timer: Timer = $StateTimer

# !!! เช็คชื่อ Node เหล่านี้ใน Scene Tree ให้ตรงเป๊ะๆ !!!
# ถ้าชื่อไม่ตรง หรือยังไม่ได้สร้าง Node เหล่านี้ เกมจะ Error ทันทีครับ
@onready var hb_melee: Area2D = $HitboxMelee
@onready var hb_range: Area2D = $RangeHitbox
@onready var hb_super: Area2D = $SuperHitbox

# -------------------- 3. VARIABLES (ตัวแปรระบบ) --------------------
enum BossState { SLEEP, WAKE, ACTIVE, ATTACK, DEAD }
var state: int = BossState.SLEEP
var facing: int = 1 
var busy: bool = false 

# ระบบ Hitbox (ตัวแปรที่ใช้จำค่าขณะโจมตี)
var is_active_frame: bool = false   # ถึงเฟรมที่ทำดาเมจหรือยัง?
var current_damage: int = 0         # ดาเมจของท่าปัจจุบัน
var active_hitbox: Area2D = null    # เก็บว่าตอนนี้ใช้ Hitbox อันไหนอยู่
var hit_targets: Array[Node] = []   # เก็บรายชื่อคนที่โดนไปแล้ว (กันโดนซ้ำ)

# -------------------- 4. MAIN LOOP --------------------
func _ready() -> void:
	hp = max_hp
	
	# เชื่อมต่อ Signal อัตโนมัติ (กันลืมต่อใน Editor)
	if not anim.frame_changed.is_connected(_on_anim_frame_changed):
		anim.frame_changed.connect(_on_anim_frame_changed)
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)
	
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	# เริ่มต้น
	_play_anim("sleep")
	state = BossState.SLEEP
	
	# เปิดการทำงานของ Hitbox รอไว้เลย (แต่เราจะเช็คด้วยโค้ดเอง)
	# ถ้า Error ตรงนี้ แปลว่าคุณไม่มี Node ชื่อ HitboxMelee/Range/Super
	if hb_melee: hb_melee.monitoring = true; hb_melee.monitorable = true
	if hb_range: hb_range.monitoring = true; hb_range.monitorable = true
	if hb_super: hb_super.monitoring = true; hb_super.monitorable = true

func _physics_process(delta: float) -> void:
	if state == BossState.DEAD: return

	# แรงโน้มถ่วง
	if not is_on_floor():
		velocity.y += gravity * delta

	var player = _get_player()

	# --- STATE MACHINE ---
	match state:
		BossState.SLEEP:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			if player and global_position.distance_to(player.global_position) <= wake_radius:
				_change_state(BossState.WAKE)
				
		BossState.WAKE:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			
		BossState.ACTIVE:
			if player:
				_chase_behavior(player, delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		
		BossState.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta) # หยุดเดินตอนตี
			
			# !!! จุดเช็คดาเมจ !!!
			# ถ้าอยู่ในเฟรมที่กำหนด และมี Hitbox ถูกเลือกอยู่
			if is_active_frame and active_hitbox != null:
				_check_hitbox_collision()

	move_and_slide()
	
	# หันหน้าตาม Player (แต่ห้ามหันตอนโจมตี)
	if player and not busy and state != BossState.ATTACK and state != BossState.SLEEP:
		var dx = player.global_position.x - global_position.x
		if abs(dx) > 10:
			facing = 1 if dx > 0 else -1
			anim.flip_h = (facing == -1)
			# สั่งกลับด้าน Hitbox ทั้งหมดเตรียมไว้
			if hb_melee: hb_melee.scale.x = abs(hb_melee.scale.x) * facing
			if hb_range: hb_range.scale.x = abs(hb_range.scale.x) * facing
			if hb_super: hb_super.scale.x = abs(hb_super.scale.x) * facing

# -------------------- 5. HITBOX SYSTEM --------------------
func _check_hitbox_collision() -> void:
	# สั่งให้ Hitbox ตัวปัจจุบัน หาคนที่ยืนทับอยู่
	var bodies = active_hitbox.get_overlapping_bodies()
	
	for body in bodies:
		# ถ้าเป็น Player และยังไม่เคยโดนในรอบการโจมตีนี้
		if body.is_in_group("player") and not body in hit_targets:
			print("!!! HIT !!! Used Hitbox: ", active_hitbox.name, " Damage: ", current_damage)
			
			if body.has_method("take_damage"):
				body.take_damage(current_damage)
				hit_targets.append(body) # จดไว้ว่าโดนแล้ว

# -------------------- 6. ATTACK COMMANDS --------------------
func _do_melee() -> void:
	active_hitbox = hb_melee # เลือกใช้ Hitbox ท่าใกล้
	_start_attack("melee", dmg_melee)

# ตัวอย่างในฟังก์ชันโจมตีของคุณ
func _do_range(player_pos):
	_face_player(player_pos)
	
	# 1. สั่งเล่นอนิเมชัน
	anim.play("range")
	
	# 2. **ต้องสั่งปิด Hitbox ก่อน!** เพื่อรอเปิดตอนถึงเฟรมที่กำหนด
	hb_range.monitoring = false 
	hb_range.monitorable = false
	
	state = BossState.ATTACK
	busy = true

func _do_super() -> void:
	active_hitbox = hb_super # เลือกใช้ Hitbox ท่าไม้ตาย
	_start_attack("super", dmg_super)

# ฟังก์ชันกลางสำหรับสั่งเริ่มท่า (จะได้ไม่ต้องเขียนซ้ำ)
func _start_attack(anim_name: String, dmg: int) -> void:
	_change_state(BossState.ATTACK)
	_play_anim(anim_name)
	current_damage = dmg
	is_active_frame = false
	hit_targets.clear() # ล้างรายชื่อคนโดน เพื่อเริ่มรอบใหม่

# -------------------- 7. ANIMATION EVENTS --------------------
func _on_anim_frame_changed() -> void:
	if state != BossState.ATTACK: return
	
	var f = anim.frame
	var a = anim.animation
	
	# ตรวจสอบเฟรมตามชื่อท่า
	if a == "melee":
		if f == frame_melee_start: is_active_frame = true
		elif f >= frame_melee_end: is_active_frame = false
	# ------------------ ท่า Range (ยิงไกล) ------------------
	if anim.animation == "range":
		# สมมติว่าเฟรมที่ 6 คือจังหวะยิง (ลองปรับเลขดูถ้ายังไม่เป๊ะ)
		if anim.frame == 10:
			hb_range.monitoring = true  # เปิดดาเมจ!
			print("Range Attack HIT! at frame 6")
		
		# พอผ่านไปสักพัก หรือจบท่า ก็ปิด (กันพลาด)
		elif anim.frame == 20:
			hb_range.monitoring = false # ปิดดาเมจ

	# ------------------ ท่า Super (ท่าใหญ่) ------------------
	# หลักการเดียวกัน ลองนับดูว่าท่าใหญ่ทุบพื้นตอนเฟรมไหน
	elif anim.animation == "super":
		if anim.frame == 10: # สมมติว่าทุบเฟรม 8
			hb_super.monitoring = true
		elif anim.frame == 20:
			hb_super.monitoring = false

func _on_anim_finished() -> void:
	# จบท่าโจมตี ให้รีเซ็ตค่า
	if anim.animation in ["melee", "range", "super"]:
		is_active_frame = false
		active_hitbox = null
		_change_state(BossState.ACTIVE) # กลับมาเดินต่อ
		
	elif anim.animation == "wake":
		_change_state(BossState.ACTIVE)
	elif anim.animation == "death":
		queue_free()

# -------------------- 8. AI DECISION --------------------
func _on_state_timer_timeout() -> void:
	if state != BossState.ACTIVE or busy: 
		state_timer.start(0.2); return
		
	var player = _get_player()
	if not player: state_timer.start(1.0); return
	
	var dist = global_position.distance_to(player.global_position)
	var rng = randf()
	
	# เลือกท่าตามระยะ
	if dist <= dist_melee:
		# ใกล้: เน้นฟัน (70%)
		if rng < 0.7: _do_melee()
		else: _do_super()
	elif dist <= dist_range:
		# กลาง: เน้นตียาว (60%)
		if rng < 0.6:
			_do_range(player.global_position)  # ใส่ player.global_position เข้าไป
		elif rng < 0.8: _do_super()
		else: state_timer.start(decision_cooldown) # เดินต่อ
	elif dist <= chase_radius:
		# ไกล: เดินไล่
		state_timer.start(decision_cooldown)
	else:
		state_timer.start(decision_cooldown)

# -------------------- 9. UTILS --------------------
func _chase_behavior(player: Node2D, delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	velocity.x = move_toward(velocity.x, sign(dx) * move_speed, accel * delta)
	
	if abs(velocity.x) > 10: _play_anim("move")
	else: _play_anim("idle")

func _change_state(new_state: int) -> void:
	state = new_state
	if state == BossState.WAKE:
		busy = true
		_play_anim("wake")
	elif state == BossState.ACTIVE:
		busy = false
		state_timer.start(decision_cooldown)

func _play_anim(name: String) -> void:
	if anim.animation != name: anim.play(name)

func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: return players[0] as Node2D
	return null

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		state = BossState.DEAD
		velocity = Vector2.ZERO
		_play_anim("death")

# ฟังก์ชันสำหรับหันหน้าหาผู้เล่น
func _face_player(target_pos: Vector2) -> void:
	# เช็คว่าผู้เล่นอยู่ทางขวาของบอสหรือไม่? (ค่า X มากกว่า = ทางขวา)
	if target_pos.x > global_position.x:
		# --- หันขวา ---
		anim.flip_h = true   # กลับด้านรูป (เพราะรูปต้นฉบับหันซ้าย)
		
		# กลับด้าน Hitbox ทั้งหมดให้ไปตีทางขวาด้วย (สำคัญมาก!)
		hb_melee.scale.x = -1
		hb_range.scale.x = -1
		hb_super.scale.x = -1
		
	else:
		# --- หันซ้าย (ปกติ) ---
		anim.flip_h = false
		
		# คืนค่า Hitbox ให้กลับมาตีทางซ้าย
		hb_melee.scale.x = 1
		hb_range.scale.x = 1
		hb_super.scale.x = 1
