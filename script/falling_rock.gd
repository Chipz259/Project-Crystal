extends Area2D

@export var fall_speed := 1200.0
@export var lifetime_on_ground := 0.4
var target_y := 0.0
var landed := false

func drop_to(y: float) -> void:
	target_y = y

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if landed:
		lifetime_on_ground -= delta
		if lifetime_on_ground <= 0:
			queue_free()
		return

	global_position.y += fall_speed * delta
	if global_position.y >= target_y:
		global_position.y = target_y
		landed = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(1)
