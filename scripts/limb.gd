extends RigidBody2D

var part_name = ""
var part_size = Vector2(8, 40)
var part_color = Color("#f4f7ff")
var shape_kind = "pill"


func setup(p_name, p_size, p_color, _p_accent, p_shape_kind):
	part_name = p_name
	part_size = p_size
	part_color = p_color
	shape_kind = p_shape_kind

	mass = 0.45
	gravity_scale = 1.0
	linear_damp = 1.15
	angular_damp = 1.8
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	collision_layer = 4
	collision_mask = 3

	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape"

	if shape_kind == "circle":
		var circle = CircleShape2D.new()
		circle.radius = part_size.x
		collision.shape = circle
	else:
		var capsule = CapsuleShape2D.new()
		capsule.radius = minf(part_size.x * 0.5, part_size.y * 0.45)
		capsule.height = maxf(part_size.y, capsule.radius * 2.0)
		collision.shape = capsule

	add_child(collision)
	queue_redraw()


func _draw():
	# Detached body parts use exactly the same solid fill as the fighter.
	if shape_kind == "circle":
		draw_circle(
			Vector2.ZERO,
			part_size.x,
			part_color
		)
		return

	var width = part_size.x
	var height = part_size.y
	var radius = width * 0.5
	var half_body = maxf(height * 0.5 - radius, 0.0)

	draw_rect(
		Rect2(
			-width * 0.5,
			-half_body,
			width,
			half_body * 2.0
		),
		part_color
	)

	draw_circle(
		Vector2(0.0, -half_body),
		radius,
		part_color
	)

	draw_circle(
		Vector2(0.0, half_body),
		radius,
		part_color
	)
