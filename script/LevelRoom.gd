extends Node2D

@onready var enemies_node = $Enemies
#@onready var boss1_node = $Boss1
@export var is_final_boss: bool = false
@export var is_miniboss: bool = false
@onready var entry_point = $EntryPoint
@onready var player_scene = preload("res://scenes/player.tscn")

# 📌 ลากไฟล์ UpgradePanelEndless.tscn มาใส่ตรงนี้ (เฉพาะในฉากบอส)
@export var upgrade_panel_scene: PackedScene 

var level_finished = false

func _ready():
	spawn_player()
	buff_enemies()

func _process(delta):
	if level_finished: return
	
	# เช็คว่ามอนตายหมดยัง
	var all_dead = true
	if enemies_node.get_child_count() > 0:
		for enemy in enemies_node.get_children():
			if enemy.get("hp") > 0:
				all_dead = false
				break
	
	# เงื่อนไขจบด่าน: ตายหมด หรือไม่มีศัตรูแต่แรก (กรณีบอส queue_free ตัวเอง)
	if (all_dead and enemies_node.get_child_count() > 0) or (is_final_boss and enemies_node.get_child_count() == 0):
		finish_level()

func finish_level():
	if level_finished: return
	level_finished = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameState.current_hp = player.hp
		GameState.current_energy = player.energy
		print("Saved Player State: HP=", player.hp, " Energy=", player.energy)
	
	if is_final_boss:
		print("BOSS DOWN! Spawning Upgrade Panel...")
		await get_tree().create_timer(1.5).timeout # รอ Effect ระเบิดแป๊บนึง
		
		# ✅ เสกหน้าต่างอัปเกรดขึ้นมาทับเลย
		if upgrade_panel_scene:
			var panel = upgrade_panel_scene.instantiate()
			add_child(panel) # ใส่ลงใน Scene นี้แหละ
			panel.open()     # สั่งเปิด (เกมจะ Pause เองตามโค้ดใน Panel)
		else:
			print("Error: ลืมลาก UpgradePanelEndless มาใส่ใน LevelRoom!")
			GameManager.load_next_level() # กันเหนียว ไปต่อเลย
	elif is_miniboss:
		# ✅ 2. ถ้าเป็น MiniBoss ให้ไป Shop
		print("MiniBoss Down! Going to Shop...")
		await get_tree().create_timer(1.0).timeout
		GameManager.load_shop()
	else:
		# ถ้าไม่ใช่บอส ก็รอแป๊บแล้วไปด่านต่อไป
		await get_tree().create_timer(1.0).timeout
		GameManager.load_next_level()

func spawn_player():
	var player = player_scene.instantiate()
	if entry_point:
		player.global_position = entry_point.global_position
	add_child(player)
	
	# ✅ LOAD: เช็คว่ามีค่าเลือดฝากไว้ใน GameState ไหม?
	if GameState.current_hp != -1:
		player.hp = GameState.current_hp
		player.energy = GameState.current_energy
		# ถ้ามี GUI หลอดเลือด ต้องสั่งอัปเดตตรงนี้ด้วย (เช่น player.update_ui())

func buff_enemies():
	var multiplier = GameManager.difficulty_multiplier
	for enemy in enemies_node.get_children():
		if enemy.has_method("buff_stats"):
			enemy.buff_stats(multiplier)
	#for enemy in boss1_node.get_children():
		#if enemy.has_method("buff_stats"):
			#enemy.buff_stats(multiplier)
