extends Area2D

@export var speed := 150.0
var target: Node2D


func _physics_process(delta):
	if target == null:
		return

	var dir := (target.global_position - global_position)
	if dir.length() == 0:
		return

	dir = dir.normalized()
	# ใช้ dir ตรง ๆ เลย ไม่ต้อง lerp
	global_position += dir * speed * delta

func _on_body_entered(body):
	print("arrow hit:", body)
	if body.is_in_group("player"):
		body.on_projectile_hit(self)

func _ready():
	print("Arrow spawned, initial target =", target)
