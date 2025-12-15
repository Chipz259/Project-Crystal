# Transition.gd (Autoload as "Transition")
extends CanvasLayer

@export var fade_out_time: float = 1.5
@export var fade_in_time: float = 3.0

# typewriter
@export var type_speed: float = 0.05
@export var after_type_delay: float = 1.5

# ✅ zoom-in during fade-out (0.6 = zoom in, 1.0 = normal)
@export var zoom_in_factor: float = 0.65  # < 1.0 = zoom IN, > 1.0 = zoom OUT
@export var zoom_ease: float = 1.0 # 1.0 = linear-ish, 0.0 = more smooth (ใช้ easing ใน tween ด้านล่าง)

@export var upgrade_panel_scene: PackedScene = preload("res://scenes/UpgradePanel.tscn")

var _overlay: ColorRect
var _label: Label
var _is_busy := false
var _typing := false
var _prev_paused := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	# White overlay
	_overlay = ColorRect.new()
	_overlay.color = Color.WHITE
	_overlay.anchor_left = 0
	_overlay.anchor_top = 0
	_overlay.anchor_right = 1
	_overlay.anchor_bottom = 1
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	# Story label (black text)
	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_top = 0.5
	_label.anchor_right = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -420
	_label.offset_right = 420
	_label.offset_top = -80
	_label.offset_bottom = 80
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 22)
	_label.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_label)

	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_label.visible = false
	_label.modulate = Color(0, 0, 0, 0)

func _freeze_world(on: bool) -> void:
	if on:
		_prev_paused = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _prev_paused

func fade_in_from_white_async(time: float = -1.0) -> void:
	if time < 0.0:
		time = fade_in_time
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # ✅ ทำงานแม้ paused
	t.tween_property(_overlay, "modulate:a", 0.0, time)
	await t.finished

func _type_text(text: String) -> void:
	_label.text = text
	_label.visible_characters = 0
	_label.visible = true
	_label.modulate = Color(0, 0, 0, 1.0)

	_typing = true
	var total := text.length()
	for i in range(total):
		if not _typing:
			break
		_label.visible_characters = i + 1
		await get_tree().create_timer(type_speed, true, false, true).timeout

	_label.visible_characters = total
	_typing = false

func boss_clear_to_scene(next_scene: String, story_text: String = "") -> void:
	if _is_busy:
		return
	_is_busy = true

	Engine.time_scale = 1.0

	# ✅ freeze เกมทั้งหมด
	_prev_paused = get_tree().paused
	get_tree().paused = true

	# สร้างกล้องชั่วคราวเพื่อซูม
	var cam: Camera2D = await _make_temp_camera_on_player()

	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.set("invincible", true)

	# 1) Fade to white + zoom in พร้อมกัน
	_overlay.visible = true
	_overlay.modulate.a = 0.0

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# fade
	tw.tween_property(_overlay, "modulate:a", 1.0, fade_out_time)

	# zoom (ถ้ามี player)
	if cam != null:
		var z := Vector2(zoom_in_factor, zoom_in_factor)
		var zoom_t := tw.parallel().tween_property(cam, "zoom", z, fade_out_time)
		zoom_t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# focus ตาม player ระหว่างเฟด เผื่อ player ไม่อยู่กลาง
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var pos_t := tw.parallel().tween_property(cam, "global_position", player.global_position, fade_out_time)
			pos_t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tw.finished

	# 2) Type story
	if story_text.strip_edges() != "":
		await _type_text(story_text)
		await get_tree().create_timer(after_type_delay, true, false, true).timeout
		_label.visible = false
		_label.modulate.a = 0.0

	# ✅ 3) ขณะยัง “ขาวเต็มจอ” ให้ขึ้น Upgrade เลย
	await _show_upgrade_on_white()

	# ✅ save player hp/energy ก่อนเปลี่ยนฉาก
	if p:
		GameState.save_player_state(int(p.get("hp")), int(p.get("energy")))

	# ลบกล้องชั่วคราว (ของฉากเก่า) ถ้ายังอยู่
	if is_instance_valid(cam):
		cam.queue_free()

	# 4) เปลี่ยนฉากไป hub/shop (ยังขาวอยู่)
	get_tree().change_scene_to_file(next_scene)
	
	# เข้า scene ใหม่ปุ๊บ เดินได้เลย
	get_tree().paused = _prev_paused

	# ปิดอมตะใน scene ใหม่ (รอ 1 เฟรมให้ player ใหม่เกิดก่อน)
	await get_tree().process_frame
	var p2 := get_tree().get_first_node_in_group("player")
	if p2:
		p2.set("invincible", false)

	# แล้วค่อยจางขาว
	await fade_in_from_white_async()

func _show_upgrade_on_white() -> void:
	if upgrade_panel_scene == null:
		return

	var up = upgrade_panel_scene.instantiate()
	add_child(up)  # ✅ อยู่ใน Transition layer สูงกว่า overlay แน่นอน
	up.process_mode = Node.PROCESS_MODE_ALWAYS

	# ถ้า up เป็น CanvasLayer ให้ดัน layer ให้สูงกว่า Transition นิดนึง
	if up is CanvasLayer:
		up.layer = layer + 1

	# เปิดแบบ "ไม่ให้มันไปยุ่ง pause" เพราะ Transition จะ pause เอง
	if up.has_method("open"):
		up.open(false)

	# รอจนกดเลือก
	if up.has_signal("picked"):
		await up.picked

	up.queue_free()

func _make_temp_camera_on_player() -> Camera2D:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null

	var cam := Camera2D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.global_position = player.global_position
	cam.zoom = Vector2.ONE
	get_tree().current_scene.add_child(cam)
	cam.make_current()

	# กันโดนกล้องอื่นแย่ง current
	await get_tree().process_frame
	cam.make_current()
	return cam
