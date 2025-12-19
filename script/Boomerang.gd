extends Area2D

@export var speed := 520.0
@export var max_dist := 520.0
@export var return_speed := 700.0

var shooter: Node2D
var dir := Vector2.RIGHT
var start_pos := Vector2.ZERO
var returning := false

@onready var anim: AnimatedSprite2D = $Anim

func _ready() -> void:
	start_pos = global_position
	if anim:
		anim.play("spin") # ชื่ออนิเมชั่นใน AnimatedSprite2D

func setup(_shooter: Node2D, _dir: Vector2) -> void:
	shooter = _shooter
	dir = _dir.normalized()

func _physics_process(delta: float) -> void:
	if shooter == null:
		queue_free()
		return

	if not returning:
		global_position += dir * speed * delta
		if global_position.distance_to(start_pos) >= max_dist:
			returning = true
	else:
		var to_shooter = shooter.global_position - global_position
		global_position += to_shooter.normalized() * return_speed * delta
		if to_shooter.length() < 24.0:
			queue_free()
