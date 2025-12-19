extends Area2D

@export var upgrade_panel_path: NodePath  # ลากไปใส่ CanvasLayer/Panel ในฉากหลัก

var _player_in_range := false

func screen_shake(amount := 8.0, duration := 0.2):
	var cam := $Camera2D
	if not cam:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	# เขย่าแบบสุ่มเล็กน้อย
	tween.tween_property(cam, "offset", Vector2(randf()*amount, randf()*amount), duration / 2)
	tween.tween_property(cam, "offset", Vector2.ZERO, duration / 2)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		print("INTERACT pressed in shrine!")
		var panel := get_node_or_null(upgrade_panel_path)
		print("panel node =", panel)
		if panel and panel.has_method("open"):
			panel.open()
		else:
			print("panel is null OR no open() method")

func _on_body_entered(body: Node) -> void:
	print("Shrine body entered:", body.name, " groups:", body.get_groups())
	if body.is_in_group("player"):
		_player_in_range = true
		print("Player in range = true")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
