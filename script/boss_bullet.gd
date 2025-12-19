extends Area2D

@export var speed := 520.0
@export var lifetime := 3.0

var velocity := Vector2.ZERO
var shooter: Node = null

func setup(from_pos: Vector2, to_pos: Vector2, _shooter: Node, _speed: float = -1.0) -> void:
	global_position = from_pos
	shooter = _shooter
	if _speed > 0: speed = _speed
	var dir := (to_pos - from_pos)
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	velocity = dir.normalized() * speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	monitoring = false
	monitorable = false
	await get_tree().process_frame
	monitoring = true
	monitorable = true

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.is_in_group("player"):
		body.on_projectile_hit(self)
	queue_free()

func _on_area_entered(a: Area2D) -> void:
	if a == shooter:
		return
	# ถ้าอยากให้ชน Hurtbox ผู้เล่นก็เช็คกลุ่ม/owner ตรงนี้เพิ่ม
