extends CharacterBody2D

@export var perfect_block_window := 0.2  # เวลาบล็อกพอดีตอนกระสุนชน
@export var energy_projectile_scene : PackedScene = preload("res://scenes/energy.tscn")
@onready var animated_sprite := $AnimatedSprite2D # แก้ path ให้ตรงกับของโปเต้

var energy := 0
var blocking := false
var block_timer := 0.0

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

enum {
	STATE_IDLE,
	STATE_RUN,
	STATE_JUMP,
	STATE_FALL,
	STATE_ATTACK,
	STATE_BLOCK
}

var state = STATE_IDLE
var previous_state = null

func _physics_process(delta): #FSM
	handle_movement(delta)
	update_state()
	play_animation()
	move_and_slide()

func handle_movement(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
func update_state(): #FSM
	# Jumping
	if not is_on_floor():
		if velocity.y < 0:
			state = STATE_JUMP
		else:
			state = STATE_FALL
		return
	# On floor

	if abs(velocity.x) > 10:
		state = STATE_RUN
	else:
		state = STATE_IDLE
			


func play_animation(): #FSM_animation
	if state == previous_state:
		return #ไม่ให้ Animation looping

	match state:
		STATE_IDLE:
			animated_sprite.play("idle")
		STATE_RUN:
			animated_sprite.play("run")
		STATE_JUMP:
			animated_sprite.play("jump")
		STATE_FALL:
			animated_sprite.play("fall")
			
	previous_state = state

	move_and_slide()

func _ready():
	add_to_group("player")
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
		print("SHOOT ENERGY, energy =", energy)
		shoot_energy()
		energy -= 1

func on_projectile_hit(projectile):
	# ---------------------------
	# ขณะถูกกระสุนชน ตรวจว่าบล็อกทันหรือไม่
	# ---------------------------
	if blocking:
		# บล็อกสำเร็จ → เปลี่ยน projectile เป็น energy
		energy += 1
		projectile.queue_free()
		print("Blocked! Energy =", energy)
	else:
		# โดนจริง → ลดเลือดตามต้องการ
		print("Player hit!")
		flash_damage()
		get_tree().current_scene.call("screen_shake")
		projectile.queue_free()

func shoot_energy():
	var e = energy_projectile_scene.instantiate()
	e.global_position = global_position

	# คำนวณทิศจาก player ไปเมาส์
	var mouse_pos = get_global_mouse_position()
	e.direction = (mouse_pos - global_position).normalized()

	# ยิงแรงขึ้นตาม energy สะสม
	e.power = energy

	get_parent().add_child(e)

func flash_damage():
	var tween := create_tween()

	animated_sprite.modulate = Color(1, 1, 1, 1)  # reset

	# กระพริบขาว → กลับเป็นปกติ 2 ครั้ง
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1).as_relative()
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
