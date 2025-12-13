extends Area2D

@export var next_scene := "res://scenes/map_1.tscn"

@onready var prompt: Label = $Prompt

var player_in := false

func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player_in and Input.is_action_just_pressed("interact"):
		print("Exit interact pressed")
		get_tree().change_scene_to_file(next_scene)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in = false
		prompt.visible = false
