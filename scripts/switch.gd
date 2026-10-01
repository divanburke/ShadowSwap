extends Area2D

var owner_game
var shadow_only = true
var active = false
var switch_position = Vector2.ZERO
var plate_size = Vector2(58, 16)
var linked_door
var label_text = "SWITCH"


func setup(game, position_value, only_shadow, display_text):
	owner_game = game
	position = position_value
	switch_position = position_value
	shadow_only = only_shadow
	label_text = display_text

	if shadow_only:
		collision_mask = 8
	else:
		collision_mask = 4

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(70, 32)
	collision.shape = shape
	add_child(collision)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func connect_door(door):
	linked_door = door
	set_switch_state(false)


func _on_body_entered(body):
	if not _can_activate(body):
		return

	set_switch_state(true)


func _on_body_exited(body):
	if not _can_activate(body):
		return

	set_switch_state(false)


func _can_activate(body):
	if body.name != "Player" and body.name != "Shadow":
		return false

	if shadow_only:
		return bool(body.get("is_shadow"))
	else:
		return not bool(body.get("is_shadow"))


func set_switch_state(value):
	active = value

	if linked_door != null:
		linked_door.call("set_open", active)

	queue_redraw()


func _draw():
	var plate_color = Color("#b993ff") if shadow_only else Color("#55d6ff")
	var dim_color = Color(plate_color, 0.25)
	var bright_color = Color(plate_color, 0.95)

	draw_rect(Rect2(-35, -10, 70, 20), Color("#11151e"), true)
	draw_rect(Rect2(-31, -6, 62, 12), bright_color if active else dim_color, true)
	draw_rect(Rect2(-31, -6, 62, 12), plate_color, false, 2.0)

	var symbol = "S" if shadow_only else "R"
	var font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(-5, 6),
		symbol,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("#f4f7ff")
	)
