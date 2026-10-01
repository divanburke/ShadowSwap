extends AnimatableBody2D

var point_a = Vector2.ZERO
var point_b = Vector2.ZERO
var travel_speed = 0.9
var travel_time = 0.0
var platform_size = Vector2(150, 22)
var fill_color = Color("#303744")
var border_color = Color("#dce5f4")


func setup(start_position, end_position, size_value, speed_value, p_fill_color, p_border_color, layer):
	position = start_position
	point_a = start_position
	point_b = end_position
	platform_size = size_value
	travel_speed = speed_value
	fill_color = p_fill_color
	border_color = p_border_color

	sync_to_physics = true
	collision_layer = layer
	collision_mask = 0

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	add_child(collision)

	queue_redraw()


func _physics_process(delta):
	travel_time += delta * travel_speed
	var amount = (sin(travel_time) + 1.0) / 2.0
	position = point_a.lerp(point_b, amount)


func _draw():
	var half = platform_size / 2.0

	draw_rect(
		Rect2(-half.x, -half.y, platform_size.x, platform_size.y),
		fill_color,
		true
	)

	draw_rect(
		Rect2(-half.x, -half.y, platform_size.x, platform_size.y),
		border_color,
		false,
		2.0
	)

	draw_line(
		Vector2(-half.x + 8, 0),
		Vector2(half.x - 8, 0),
		Color(border_color, 0.22),
		1.0
	)
