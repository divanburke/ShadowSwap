extends Area2D

var owner_game
var world_id = 1
var hazard_name = "HAZARD"
var hazard_color = Color("#ff4f73")
var hazard_size = Vector2(72, 28)


func setup(game, world, display_name, size):
	owner_game = game
	world_id = world
	hazard_name = display_name
	hazard_size = size

	if world_id == 1:
		collision_mask = 4
	elif world_id == 2:
		collision_mask = 8
	else:
		collision_mask = 12

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = hazard_size
	collision.shape = shape
	add_child(collision)

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body):
	if owner_game == null:
		return

	if body.name == "Player" or body.name == "Shadow":
		owner_game.call("player_hit", hazard_name)


func _draw():
	var half = hazard_size / 2.0
	var spike_count = max(2, int(hazard_size.x / 14.0))
	var width = hazard_size.x / spike_count
	var points = PackedVector2Array()

	for i in range(spike_count):
		var x = -half.x + i * width
		points.append(Vector2(x, half.y))
		points.append(Vector2(x + width * 0.5, -half.y))
		points.append(Vector2(x + width, half.y))

	draw_colored_polygon(points, hazard_color)
	draw_polyline(points, Color("#ffd4dc"), 1.5, true)

	draw_line(
		Vector2(-half.x, half.y),
		Vector2(half.x, half.y),
		Color("#7c2038"),
		2.0
	)
