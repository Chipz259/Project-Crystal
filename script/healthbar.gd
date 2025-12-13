extends ProgressBar

@export var free_on_zero := false
@export var damage_delay := 0.25

@export var pop_on_damage := true
@export var pop_scale := 1.08
@export var pop_in := 0.05
@export var pop_out := 0.12

var timer: Timer = null
var damage_bar: ProgressBar = null

var health: int = 0 : set = _set_health
var _pending_init_max: int = -1

func _ready() -> void:
	# หา Timer
	timer = get_node_or_null("Timer")
	if timer == null:
		timer = get_node_or_null("Timer_player")

	# หา damage bar
	damage_bar = get_node_or_null("damagebar")
	if damage_bar == null:
		damage_bar = get_node_or_null("damagebar_player")

	print("[healthbar] timer=", timer, " damage_bar=", damage_bar)

	# ตั้งค่า timer
	if timer:
		timer.one_shot = true
		timer.autostart = false
		timer.wait_time = damage_delay
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)

	# apply init ที่ค้างไว้
	if _pending_init_max > 0:
		_apply_init(_pending_init_max)

	if damage_bar:
		damage_bar.value = int(value)

func _set_health(new_health: int) -> void:
	var prev_health := health
	health = int(min(max_value, new_health))
	value = health

	if health <= 0 and free_on_zero:
		queue_free()
		return

	if damage_bar == null or timer == null:
		return

	if health < prev_health:
		_pop_bar()
		timer.start()
	elif health > prev_health:
		damage_bar.value = health

func init_health(_health: int) -> void:
	if damage_bar == null:
		_pending_init_max = _health
		max_value = _health
		health = _health
		value = health
		return

	_apply_init(_health)

func _apply_init(_health: int) -> void:
	max_value = _health
	damage_bar.max_value = _health

	health = _health
	value = health
	damage_bar.value = health

func _on_timer_timeout() -> void:
	if damage_bar:
		damage_bar.value = health

func _pop_bar() -> void:
	if not pop_on_damage:
		return
	var t := create_tween()
	scale = Vector2.ONE
	t.tween_property(self, "scale", Vector2(pop_scale, pop_scale), pop_in)
	t.tween_property(self, "scale", Vector2.ONE, pop_out).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
