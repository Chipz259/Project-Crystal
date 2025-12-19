extends Area2D

@export var base_speed := 3000.0

# direction นี้จะถูกส่งค่ามาจาก player ตอนที่สั่งยิง
var direction := Vector2.ZERO
var damage := 1
var stack := 1

# ✅ เพิ่มส่วนนี้: ทำงานครั้งแรกครั้งเดียวตอนกระสุนเกิด
func _ready():
	# 1. direction.angle() คือหามุมองศาของทิศทางที่จะไป
	# 2. เราต้องบวก PI (คือ 180 องศาในหน่วยเรเดียน) เข้าไป
	#    เหตุผล: เพราะรูป Sprite ตั้งต้นของคุณ "หัวมันหันไปทางซ้าย"
	#    แต่ใน Godot ทิศข้างหน้ามาตรฐานคือ "ทางขวา"
	#    ถ้าไม่บวก PI มันจะเอาด้านขวา (ซึ่งคือก้นกระสุน) หันไปหาเมาส์แทน
	rotation = direction.angle() + PI

func _physics_process(delta):
	# เคลื่อนที่ไปข้างหน้าตามทิศทาง
	position += direction * base_speed * delta

func _on_body_entered(body):
	print("ENERGY HIT:", body.name)
	# เพิ่มการเช็คหน่อยว่า ถ้าชนคนยิงเอง (player) ให้ข้ามไป ไม่ต้องระเบิด
	if body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
