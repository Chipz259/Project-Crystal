extends CanvasLayer

@export var fade_out_time: float = 1.2
@export var fade_in_time: float = 1.0

# typewriter
@export var type_speed: float = 0.05      # วินาทีต่อตัวอักษร
@export var after_type_delay: float = 1.5 # หน่วงหลังพิมพ์จบก่อนเปลี่ยนฉาก

var _overlay: ColorRect
var _label: Label
var _is_busy: bool = false

var _typing := false

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


func fade_in_from_white(time: float = -1.0) -> void:
	if time < 0.0:
		time = fade_in_time
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_overlay, "modulate:a", 0.0, time)


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
		# process_always=true, ignore_time_scale=true กันค้าง
		await get_tree().create_timer(type_speed, true, false, true).timeout

	_label.visible_characters = total
	_typing = false


func boss_clear_to_scene(next_scene: String, story_text: String = "") -> void:
	if _is_busy:
		return
	_is_busy = true

	# กัน time_scale ค้างจาก hitstop
	Engine.time_scale = 1.0

	# 1) Fade to white
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_overlay, "modulate:a", 1.0, fade_out_time)
	await fade.finished

	# 2) Type story on white (ถ้ามี)
	if story_text.strip_edges() != "":
		await _type_text(story_text)
		await get_tree().create_timer(after_type_delay, true, false, true).timeout
		_label.visible = false
		_label.modulate.a = 0.0

	# 3) Change scene (ยังขาวอยู่)
	get_tree().change_scene_to_file(next_scene)

	# 4) Fade in ในฉากใหม่
	await get_tree().process_frame
	fade_in_from_white()

	_is_busy = false
