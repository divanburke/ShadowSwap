extends RigidBody2D

var part_name = ""
var part_size = Vector2(20, 20)
var part_color = Color("#f4f7ff")
var accent_color = Color("#55d6ff")
var shape_kind = "rect"
var shadowed = false
var hit_flash = 0.0


func setup(p_name, p_size, p_color, p_accent, p_shape_kind):
	part_name = p_name
	part_size = p_size
	part_color = p_color
	accent_color = p_accent
	shape_kind = p_shape_kind

	match part_name:
		"torso":
			mass = 1.30
			linear_damp = 1.20
			angular_damp = 2.80
		"head":
			mass = 0.55
			linear_damp = 1.40
			angular_damp = 2.20
		"left_arm", "right_arm":
			mass = 0.32
			linear_damp = 1.70
			angular_damp = 2.40
		"left_leg", "right_leg":
			mass = 0.48
			linear_damp = 1.45
			angular_damp = 2.60
		_:
			mass = 0.60
			linear_damp = 1.50
			angular_damp = 2.50

	gravity_scale = 1.0
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	# Layer 1 is the arena. Layer 2 is other fighter body parts.
	# This lets characters push against platforms and each other.
	collision_layer = 2
	collision_mask = 3

	var collision = CollisionShape2D.new()
	var shape

	if shape_kind == "circle":
		shape = CircleShape2D.new()
		shape.radius = part_size.x
	else:
		shape = RectangleShape2D.new()
		shape.size = part_size

	collision.shape = shape
	add_child(collision)

	queue_redraw()


func set_shadowed(value):
	shadowed = value
	queue_redraw()


func flash_hit():
	hit_flash = 0.12
	queue_redraw()


func _physics_process(delta):
	if hit_flash > 0.0:
		hit_flash = maxf(hit_flash - delta, 0.0)
		queue_redraw()


func _draw():
	var body_color = part_color
	var border_color = accent_color

	if shadowed:
		body_color = Color(
			minf(part_color.r + 0.20, 1.0),
			minf(part_color.g + 0.20, 1.0),
			minf(part_color.b + 0.20, 1.0),
			0.92
		)
		border_color = Color("#c9b5ff")

	if hit_flash > 0.0:
		body_color = Color("#ffffff")
		border_color = Color("#ffffff")

	if shape_kind == "circle":
		draw_circle(Vector2.ZERO, part_size.x, body_color)
		draw_arc(Vector2.ZERO, part_size.x, 0.0, TAU, 32, border_color, 2.0)
		draw_circle(Vector2(-5, -4), 2.3, border_color)
		draw_circle(Vector2(5, -4), 2.3, border_color)
	else:
		var rect = Rect2(-part_size / 2.0, part_size)
		var box = StyleBoxFlat.new()
		box.bg_color = body_color
		box.border_color = border_color
		box.set_border_width_all(2)
		box.corner_radius_top_left = 6
		box.corner_radius_top_right = 6
		box.corner_radius_bottom_left = 6
		box.corner_radius_bottom_right = 6
		draw_style_box(box, rect)
