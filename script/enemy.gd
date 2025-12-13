extends CharacterBody2D

@export var shard_popup_scene: PackedScene = preload("res://scenes/ShardPopup.tscn")

@export var max_hp := 5
var hp := 0

@export var shard_reward: int = 1
var core_reward: int = 1

@export var shoot_interval := 2.0
@export var projectile_speed := 150.0
@export var projectile_scene : PackedScene = preload("res://scenes/arrow.tscn")
@onready var healthbar = $healthbar

var shoot_timer := 0.0
var player : Node2D

func _ready():
	add_to_group("enemy")
	hp = max_hp
	if healthbar and healthbar.has_method("init_health"):
		healthbar.init_health(max_hp)

	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player != null:
			print("Enemy got player:", player)

	if player == null:
		return

	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		shoot_projectile()

func take_damage(amount: int) -> void:
	hp -= amount
	if healthbar:
		healthbar.health = hp

	if hp <= 0:
		die()

func die() -> void:
	GameState.add_shards(shard_reward)
	GameState.add_cores(core_reward)
	
	if shard_popup_scene:
		var popup = shard_popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.global_position = global_position + Vector2(0, -16)
	print("Run shards =", GameState.run_shards, " cores =", GameState.cores)
	queue_free()

func shoot_projectile():
	if projectile_scene == null:
		push_error("projectile_scene not set on Enemy!")
		return
	if player == null:
		push_error("player is null in Enemy!")
		return

	var p = projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.target = player
	p.speed = projectile_speed
