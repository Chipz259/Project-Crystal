# ShardPopup.gd
extends Node2D

@export var fade_time := 0.35  # ปรับให้ช้าหรือเร็วได้
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if sprite == null:
		queue_free()
		return

	# เริ่มจากทึบเต็ม
	sprite.modulate.a = 1.0

	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, fade_time)
	t.finished.connect(queue_free)
