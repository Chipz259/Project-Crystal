extends Area2D

@export var base_speed := 1500.0

var direction := Vector2.ZERO
var damage := 1
var stack := 1 # optional: เอาไว้ทำ VFX/ความเร็วตามสแต็ก

func _physics_process(delta):
	position += direction * base_speed * delta

func _on_body_entered(body):
	print("ENERGY HIT:", body.name)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
