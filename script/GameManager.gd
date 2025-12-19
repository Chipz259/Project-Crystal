extends Node

# --- ตั้งค่า Scene ใน Inspector ---
@export_category("Level Config")
@export var normal_maps: Array[PackedScene] # ลาก Map_Normal ใส่
@export var miniboss_map: PackedScene       # ลาก Map_Miniboss ใส่
@export var boss_map: PackedScene           # ลาก Map_Boss ใส่
@export var shop_map: PackedScene

var current_level: int = 0
var difficulty_multiplier: float = 1.0
var last_map_index: int = -1 

func start_game():
	GameState.reset_player_state()
	current_level = 0 
	difficulty_multiplier = 1.0
	load_next_level()

func load_next_level():
	# 1. เพิ่มเลเวลและความยาก
	current_level += 1
	difficulty_multiplier += 0.1 
	print("Loading Level: ", current_level, " (Diff: ", difficulty_multiplier, ")")
	
	# 2. คำนวณด่านถัดไป
	var next_map = null 
	
	if current_level % 10 == 0:
		next_map = boss_map
	elif current_level % 5 == 0:
		next_map = miniboss_map
	else:
		# สุ่มแมพปกติ
		if normal_maps.size() > 0:
			if normal_maps.size() == 1:
				next_map = normal_maps[0]
			else:
				var new_index = randi() % normal_maps.size()
				while new_index == last_map_index:
					new_index = randi() % normal_maps.size()
				last_map_index = new_index
				next_map = normal_maps[new_index]
	
	# 3. เปลี่ยนฉาก
	if next_map:
		Transition.change_scene(next_map.resource_path)
	else:
		print("Error: หา next_map ไม่เจอ! (เช็ค Inspector ของ GameManager)")

func load_shop():
	print("Go to Shop! (Level not increased)")
	if shop_map:
		Transition.change_scene(shop_map.resource_path)
	else:
		print("Error: ลืมใส่ไฟล์ ShopEndless ใน GameManager!")
		load_next_level() # กันค้าง ถ้าลืมใส่ก็ไปด่านหน้าเลย
