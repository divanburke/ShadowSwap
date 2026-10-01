extends StaticBody2D

var platform_size = Vector2(200, 30)
var fill_color = Color("#2b303a")
var border_color = Color("#4a5363")


func setup(p_size, p_fill, p_border):
	platform_size = p_size
	fill_color = p_fill
	border_color = p_border

	collision_layer = 1
	collision_mask = 0

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	add_child(collision)

	queue_redraw()


func _draw():
	var rect = Rect2(-platform_size / 2.0, platform_size)

	var box = StyleBoxFlat.new()
	box.bg_color = fill_color
	box.border_color = border_color
	box.set_border_width_all(2)
	box.corner_radius_top_left = 9
	box.corner_radius_top_right = 9
	box.corner_radius_bottom_left = 9
	box.corner_radius_bottom_right = 9

	draw_style_box(box, rect)

	draw_line(
		Vector2(-platform_size.x / 2.0 + 12, -platform_size.y / 2.0 + 5),
		Vector2(platform_size.x / 2.0 - 12, -platform_size.y / 2.0 + 5),
		Color(border_color, 0.35),
		1.0
	)
