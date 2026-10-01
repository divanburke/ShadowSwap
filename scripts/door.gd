extends AnimatableBody2D

var closed_position = Vector2.ZERO
var open_position = Vector2.ZERO
var door_size = Vector2(30, 150)
var is_open = false
var door_color = Color("#55d6ff")


func setup(position_value, size_value, color_value):
	position = position_value
	closed_position = position_value
	open_position = position_value + Vector2(0, -size_value.y - 12)
	door_size = size_value
	door_color = color_value

	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = door_size
	collision.shape = shape
	add_child(collision)

	queue_redraw()


func set_open(value):
	if is_open == value:
		return

	is_open = value

	if is_open:
		collision_layer = 0
	else:
		collision_layer = 1

	var target = open_position if is_open else closed_position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.32)

	queue_redraw()


func _draw():
	var half = door_size / 2.0

	if is_open:
		draw_rect(
			Rect2(-half.x, -half.y, door_size.x, 5),
			Color(door_color, 0.25),
			true
		)
	else:
		draw_rect(
			Rect2(-half.x, -half.y, door_size.x, door_size.y),
			Color("#171b25"),
			true
		)
		draw_rect(
			Rect2(-half.x, -half.y, door_size.x, door_size.y),
			door_color,
			false,
			2.0
		)

		for y in range(8, int(door_size.y) - 8, 18):
			draw_line(
				Vector2(-half.x + 6, -half.y + y),
				Vector2(half.x - 6, -half.y + y),
				Color(door_color, 0.35),
				2.0
			)
