extends Node2D

@onready var player_scene = preload("res://scenes/player.tscn")
@onready var entry_point = $EntryPoint # (ถ้ามีจุดเกิด) ถ้าไม่มีลบออกได้
# ในรูปนายชื่อ ExitZone เช็คให้ชัวร์ว่าเป็น Area2D นะ
@onready var exit_zone = $ExitZone 

func _ready():
	spawn_player_in_shop()
	

func spawn_player_in_shop():
	# โค้ด spawn เหมือน LevelRoom แต่ไม่ต้องมีศัตรู
	var player = player_scene.instantiate()
	# กำหนดจุดเกิด (ถ้าไม่มี entry_point ให้กำหนดพิกัดเอง เช่น Vector2(100, 300))
	player.position = Vector2(300, 500) 
	add_child(player)
	
	# โหลดเลือดมาโชว์
	if GameState.current_hp != -1:
		player.hp = GameState.current_hp
		player.energy = GameState.current_energy

func _on_exit_zone_entered(body):
	if body.is_in_group("player"):
		print("Exiting Shop -> Next Level")
		
		# ✅ สำคัญ: Save เลือดล่าสุด (เผื่อซื้อของกินใน Shop)
		GameState.current_hp = body.hp
		GameState.current_energy = body.energy
		
		# ไปด่านต่อไป (Level +1)
		GameManager.load_next_level()
