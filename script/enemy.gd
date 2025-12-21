# enemy_combo_parry.gd
extends CharacterBody2D

# -------------------- CONFIG --------------------
@export_group("Stats")
@export var max_hp: int = 1
@export var hp: int = 1
@onready var health_bar = $healthbar
@export var move_speed: float = 80.0
@export var gravity: float = 900.0
@export var min_shards: int = 1     # ค่าต่ำสุด (ปรับใน Inspector)
@export var max_shards: int = 3     # ค่าสูงสุด (ปรับใน Inspector)
@export var shard_popup_scene: PackedScene

@export_group("AI")
@export var detect_range: float = 400.0
@export var attack_range: float = 70.0 # ปรับให้พอดีกับท่าแรก
@export var attack_cooldown: float = 2.0

@export_group("Combat Combo")
# ความแรงท่า 1 และ 2
@export var dmg_hit1: int = 1
@export var dmg_hit2: int = 2
# จังหวะเวลา (สำคัญมาก! ต้องจูนให้ตรงกับอนิเมชัน)
@export var time_windup1: float = 0.6   # เวลาง้างท่า 1
@export var time_active1: float = 0.2   # เวลาเปิด Hitbox ท่า 1
@export var time_between: float = 0.3   # เวลาพักระหว่างท่า 1 กับ 2
@export var time_active2: float = 0.2   # เวลาเปิด Hitbox ท่า 2

# -------------------- NODES --------------------
@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
# !!! สำคัญ: ต้องตั้งชื่อ CollisionShape2D ใน Hitbox ให้ตรงตามนี้ !!!
@onready var shape1: CollisionShape2D = $Hitbox/ShapeHit1
@onready var shape2: CollisionShape2D = $Hitbox/ShapeHit2

@export_group("Miniboss Settings")
@export var is_miniboss: bool = false  # ติ๊กถูกถ้าจะให้เป็นบอส
@export var boss_scale: float = 1.5    # ขนาดตัวคูณ (1.5 เท่า)
@export var boss_hp_multiplier: int = 3 # เลือดคูณ 3 เท่า

# -------------------- STATE --------------------
enum State { IDLE, CHASE, ATTACK, HURT, STUNNED, DEAD }
var state: int = State.IDLE
var player: Node2D = null
var can_attack: bool = true
var facing: int = 1
var current_hit_damage: int = 0 # ดาเมจของจังหวะปัจจุบัน

func _ready() -> void:
	if is_miniboss:
		# 1. ขยายร่าง! (ขยายที่ Root Node ทีเดียว ลูกๆ จะขยายตามหมด)
		scale = Vector2(boss_scale, boss_scale)
		# 2. เพิ่มเลือด!
		max_hp *= boss_hp_multiplier
		hp = max_hp
		# 3. (ออพชั่นเสริม) อาจจะทำให้เดินช้าลงหน่อยให้ดูหนักแน่น
		move_speed *= 0.8
		print("Miniboss Spawned! HP:", max_hp)
		min_shards = 20   # พอเป็นบอสปุ๊บ ให้ดรอปต่ำสุด 20
		max_shards = 30   # สูงสุด 30

	hp = max_hp
	if health_bar:
		health_bar.init_health(max_hp)
		health_bar.visible = false
	# เริ่มมาปิดให้หมดทุก Shape
	hitbox.monitoring = false
	shape1.set_deferred("disabled", true)
	shape2.set_deferred("disabled", true)

	hitbox.body_entered.connect(_on_hitbox_body_entered)
	anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta: float) -> void:
	if state == State.DEAD: return

	if not is_on_floor():
		velocity.y += gravity * delta

	player = _get_player()

	match state:
		State.IDLE:
			velocity.x = 0
			_play_anim("idle")
			if player and global_position.distance_to(player.global_position) <= detect_range:
				state = State.CHASE

		State.CHASE:
			if not player: state = State.IDLE; return
			var dist = global_position.distance_to(player.global_position)
 
			if dist <= attack_range and can_attack:
				_start_combo_attack() # เรียกฟังก์ชันคอมโบใหม่
			elif dist > detect_range * 1.5:
				state = State.IDLE
			else:
				var dir = (player.global_position.x - global_position.x)
				facing = 1 if dir > 0 else -1
				velocity.x = facing * move_speed
				_play_anim("run")

		State.ATTACK, State.HURT, State.STUNNED:
			velocity.x = 0 # หยุดเดิน

	move_and_slide()
	_update_facing()

# -------------------- COMBO ACTIONS --------------------
# ฟังก์ชันเริ่มโจมตีแบบ 2 จังหวะ
func _start_combo_attack() -> void:
	state = State.ATTACK
	can_attack = false
	_play_anim("attack") # สมมติว่าอนิเมชัน "attack" เล่นยาวทั้ง 2 ท่ารวมกัน

	# --- จังหวะที่ 1 ---
	await get_tree().create_timer(time_windup1).timeout
	if state != State.ATTACK: return # เช็คเผื่อโดนขัดจังหวะ
	
	print("Hit 1 Active!")
	current_hit_damage = dmg_hit1
	shape1.set_deferred("disabled", false) # เปิด Shape 1
	hitbox.monitoring = true
	await get_tree().create_timer(time_active1).timeout
	hitbox.monitoring = false
	shape1.set_deferred("disabled", true)  # ปิด Shape 1

	# --- พักระหว่างท่า ---
	await get_tree().create_timer(time_between).timeout
	if state != State.ATTACK: return

	# --- จังหวะที่ 2 ---
	print("Hit 2 Active! (High attack)")
	current_hit_damage = dmg_hit2
	shape2.set_deferred("disabled", false) # เปิด Shape 2 (อันเล็กและสูง)
	hitbox.monitoring = true
	await get_tree().create_timer(time_active2).timeout
	hitbox.monitoring = false
	shape2.set_deferred("disabled", true) # ปิด Shape 2

	# รอ Cooldown หลังจบท่า
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# -------------------- COMBAT SYSTEM (PARRY SUPPORT) --------------------
# เมื่อ Hitbox ชน Player
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# เช็คว่า Player มีระบบรับการโจมตีแบบใหม่มั้ย
		if body.has_method("handle_incoming_attack"):
			# ห่อข้อมูลใส่กล่อง
			var attack_data = {
				"damage": current_hit_damage, # ส่งดาเมจของท่านั้นๆ
				"direction": Vector2(facing, 0), # ทิศที่ศัตรูหัน
				"source": self, # ส่งตัวเองไปด้วย (เผื่อ Player จะสั่ง Stun กลับ)
				"can_parry": true # ท่านี้ปัดได้มั้ย?
			}
			# ส่งกล่องไปให้ Player ตัดสินใจ
			body.handle_incoming_attack(attack_data)
			print("Sent attack data to player")
		
		# ถ้า Player ไม่มีระบบใหม่ ก็ใช้ระบบเก่า (take_damage ตรงๆ)
		elif body.has_method("take_damage"):
			body.take_damage(current_hit_damage)

func take_damage(amount: int) -> void:
	if state == State.DEAD or state == State.STUNNED: return
	hp -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.health = hp  # ส่งค่า hp ปัจจุบันเข้าไป (Setter ใน healthbar.gd จะทำงานเอง)
		
	print("Enemy took damage: ", amount, " HP: ", hp)
	_interrupt_attack() # โดนตีให้หยุดโจมตี
	if hp <= 0: _die()
	else:
		state = State.HURT
		_play_anim("hurt")

# ฟังก์ชันใหม่: โดน Stun (เมื่อ Player Parry สำเร็จ)
# แก้ไขฟังก์ชันนี้ในไฟล์ Enemy
func get_stunned() -> void:
	if state == State.DEAD: return
	
	print("ENEMY STUNNED!!!")
	_interrupt_attack()
	
	# 1. เข้าสถานะมึน (ขยับไม่ได้)
	state = State.STUNNED
	_play_anim("hurt") 
	
	# รอจนกว่าจะหายมึน (เช่น 1 วินาที)
	await get_tree().create_timer(0.08).timeout
	
	# 2. หายมึนแล้ว -> กลับมาเดินไล่ (Chase)
	if state == State.STUNNED:
		state = State.CHASE 
		
		# --- จุดสำคัญอยู่ตรงนี้ครับ ---
		
		# สั่งห้ามตีก่อน! (ให้เดินวนๆ ไปก่อน)
		can_attack = false 
		
		# รออีกสักพัก (เช่น 1.5 วินาที) เป็นช่วงพักเหนื่อยหลังโดน Parry
		await get_tree().create_timer(1.5).timeout
		
		# เช็คอีกทีว่ายังไม่ตายนะ ค่อยอนุญาตให้ตีใหม่
		if state != State.DEAD:
			can_attack = true
			print("Enemy recovered and ready to attack again!")

# -------------------- UTILS --------------------
# ฟังก์ชันช่วยตัดบทการโจมตี (ใช้ตอนโดนตี หรือโดน Stun)
func _interrupt_attack() -> void:
	hitbox.monitoring = false
	shape1.set_deferred("disabled", true)
	shape2.set_deferred("disabled", true)
	# ไม่รีเซ็ต can_attack ทันที ปล่อยให้ Timer เดิมทำงานจนจบ หรือจะ reset ก็ได้

func _update_facing() -> void:
	if state in [State.ATTACK, State.HURT, State.STUNNED, State.DEAD]: return
	if velocity.x != 0:
		facing = 1 if velocity.x > 0 else -1
	anim.flip_h = (facing == -1)
	hitbox.scale.x = facing

func _on_anim_finished() -> void:
	if anim.animation == "attack":
		state = State.CHASE
	elif anim.animation == "hurt":
		if state != State.STUNNED: # ถ้าแค่เจ็บธรรมดา ให้กลับไปไล่
			state = State.CHASE
	elif anim.animation == "death":
		#z_index = -1
		anim.pause()

func _die() -> void:
	drop_loot()
	state = State.DEAD
	velocity = Vector2.ZERO
	_interrupt_attack()
	
	# --- ลบบรรทัดนี้ทิ้ง หรือ Comment ไว้ครับ ---
	# $CollisionShape2D.set_deferred("disabled", true) 
	
	# --- ใส่โค้ดชุดนี้แทน ---
	# 1. ปิด Layer ตัวเอง (เพื่อไม่ให้ Player เดินชนศพเหมือนชนกำแพง)
	collision_layer = 0 
	
	# 2. ปรับ Mask ให้เหลือแค่พื้น (เพื่อให้ศพยังยืนบนพื้นได้ ไม่ร่วง)
	# สมมติว่า "พื้น (World)" ของคุณอยู่ Layer 1 (ค่าปกติของ Godot)
	collision_mask = 1 
	
	_play_anim("death")
	health_bar.visible = false

func _play_anim(name: String) -> void:
	if anim.animation != name: anim.play(name)

func _get_player() -> Node2D:
	var nodes = get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes else null

# Debug วาดวงกลม
#func _draw() -> void:
	#draw_circle(Vector2.ZERO, detect_range, Color(0, 1, 0, 0.1))
	#draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.1))

func buff_stats(multiplier: float):
	# เพิ่มเลือดตามตัวคูณ
	max_hp = int(max_hp * multiplier)
	hp = max_hp
	
	# ถ้ามีตัวแปร damage ก็คูณ damage ด้วยได้
	# damage = int(damage * multiplier)
	
	print(name, " Buffed! HP is now: ", max_hp)

func drop_loot():
	# 1. สุ่มจำนวนพื้นฐาน (Base Amount)
	var base_amount = randi_range(min_shards, max_shards)
	
	if base_amount <= 0: return

	# 2. ส่งเข้ากระเป๋า (GameState จะบวกโบนัสให้เองในฟังก์ชัน add_shards)
	GameState.add_shards(base_amount)
	
	# 3. คำนวณยอดสุทธิเพื่อโชว์บนหัว (Base + Bonus)
	# เราต้องคำนวณตรงนี้เพื่อให้ตัวเลขที่เด้งขึ้นมา ตรงกับเงินที่ได้รับจริง
	var total_received = base_amount + GameState.shard_bonus_add
	
	print("Dropped: ", base_amount, " + Bonus: ", GameState.shard_bonus_add, " = ", total_received)

	# 4. สร้าง Popup ตัวเลขเด้ง
	if shard_popup_scene:
		var popup = shard_popup_scene.instantiate()
		popup.global_position = global_position
		
		# ส่งยอดรวมไปโชว์
		if popup.has_method("setup"):
			popup.setup(total_received)
			
		get_tree().current_scene.add_child(popup)
