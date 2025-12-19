extends Node2D

@onready var label = $Label

# ตัวแปรเก็บยอดเงิน (ตั้งค่าเริ่มต้นเป็น 0)
var amount: int = 0

func _ready():
	# 1. พอเกิดมาปุ๊บ ให้แก้ข้อความทันที
	if label:
		label.text = "+" + str(amount)
	
	# 2. เล่นอนิเมชั่นลอยขึ้น + จางหาย
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()

# ฟังก์ชันนี้แค่รับค่ามาเก็บไว้ก่อน (ยังไม่แก้ Text ตรงนี้)
func setup(val: int):
	amount = val
