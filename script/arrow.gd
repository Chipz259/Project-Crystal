# arrow.gd
extends Area2D

@export var speed := 700.0
@export var lifetime := 5.0

var target: Node2D
var shooter: Node = null
var direction := Vector2.ZERO

func _ready() -> void:
	if target == null:
		queue_free()
		return

	# ล็อกทิศตั้งแต่ยิง (ไม่ homing ระหว่างทาง)
	direction = (target.global_position - global_position).normalized()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# กันชนบอสเอง
	if body == shooter:
		return

	# โดนผู้เล่น
	if body.is_in_group("player"):
		body.on_projectile_hit(self)
		queue_free()
		return

	# ชนอะไรก็ตามที่ไม่ใช่ผู้เล่น → หาย
	queue_free()
