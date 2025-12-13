extends Node

signal run_shards_changed(value: int)
signal cores_changed(value: int)

var run_shards: int = 0
var cores: int = 0

# ✅ อัปเกรด: ได้ shard เพิ่ม “ต่อครั้งที่ได้ shard”
var shard_bonus_add: int = 0  # เช่น +1 ต่อ kill
var parry_window_bonus: float = 0.0 # เพิ่ม parry window bonus

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
	run_shards_changed.emit(run_shards)
	cores_changed.emit(cores)
