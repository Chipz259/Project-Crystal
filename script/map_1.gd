extends Node2D

func screen_shake(amount := 8.0, duration := 0.2):
	var cam := $Camera2D
	if not cam:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	# เขย่าแบบสุ่มเล็กน้อย
	tween.tween_property(cam, "offset", Vector2(randf()*amount, randf()*amount), duration / 2)
	tween.tween_property(cam, "offset", Vector2.ZERO, duration / 2)
