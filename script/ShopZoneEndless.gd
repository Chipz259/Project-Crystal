# ShopZone.gd
extends Area2D

@export var shop_panel_path: NodePath
@onready var prompt: Label = get_node_or_null("Prompt")
var _player_in := false

func _ready() -> void:
	if prompt: prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_in and Input.is_action_just_pressed("interact"):
		var panel := get_node_or_null(shop_panel_path)
		if panel and panel.has_method("open"):
			panel.open()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in = true
		if prompt: prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in = false
		if prompt: prompt.visible = false
