extends Area2D

@export var base_speed := 200.0

var direction := Vector2.ZERO
var power := 1  # พลังจะเพิ่มตาม energy ที่ผู้เล่นมีตอนยิง

func _process(delta):
	position += direction * base_speed * power * delta

func _on_body_entered(body):
	# กระสุนนี้จะชนศัตรู แกกำหนด damage เองได้
	if body.has_method("take_damage"):
		body.take_damage(power)
	queue_free()
