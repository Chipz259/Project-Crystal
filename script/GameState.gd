extends Node

signal run_shards_changed(value: int)
signal cores_changed(value: int)

var run_shards: int = 0
var cores: int = 0

# ✅ อัปเกรด: ได้ shard เพิ่ม “ต่อครั้งที่ได้ shard”
var shard_bonus_add: int = 0  # เช่น +1 ต่อ kill
var parry_window_bonus: float = 0.0 # เพิ่ม parry window bonus

var heal_bonus: int = 0
var heal_upgrade_taken: bool = false

var saved_hp: int = -1
var saved_energy: int = -1

var current_hp: int = -1       # -1 แปลว่ายังไม่มีค่า (ให้ใช้ค่าเริ่มต้น)
var current_energy: int = -1

func save_player_state(hp: int, energy: int) -> void:
	saved_hp = hp
	saved_energy = energy

func consume_player_state() -> Dictionary:
	var d := {"hp": saved_hp, "energy": saved_energy}
	saved_hp = -1
	saved_energy = -1
	return d

func add_shards(amount: int) -> void:
	if amount <= 0: return
	var final_amount := amount + shard_bonus_add
	run_shards += final_amount
	run_shards_changed.emit(run_shards)

func add_cores(amount: int) -> void:
	if amount == 0: return
	cores += amount
	cores_changed.emit(cores)

func reset_run() -> void:
	run_shards = 0
	cores = 0
	shard_bonus_add = 0
	parry_window_bonus = 0.0
	heal_bonus = 0
	heal_upgrade_taken = false
	run_shards_changed.emit(run_shards)
	cores_changed.emit(cores)
	saved_hp = -1
	saved_energy = -1

func reset_player_state():
	current_hp = -1
	current_energy = -1
	# reset โบนัสอื่นๆ ด้วยก็ได้
