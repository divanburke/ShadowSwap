extends Node2D

const FighterScript = preload("res://scripts/fighter.gd")

const VIEW_SIZE = Vector2(1152, 648)

var player


func _ready():
	build_floor()
	build_player()


func build_floor():
	var floor_body = StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(576.0, 610.0)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 2

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(1152.0, 76.0)
	collision.shape = shape

	floor_body.add_child(collision)
	add_child(floor_body)


func build_player():
	player = FighterScript.new()
	player.name = "Player"
	add_child(player)

	player.setup(
		Vector2(576.0, 525.0)
	)


func _draw():
	draw_rect(
		Rect2(Vector2.ZERO, VIEW_SIZE),
		Color("#10151b")
	)

	draw_rect(
		Rect2(0.0, 572.0, VIEW_SIZE.x, 76.0),
		Color("#252d36")
	)

	draw_line(
		Vector2(0.0, 572.0),
		Vector2(VIEW_SIZE.x, 572.0),
		Color("#39434e"),
		3.0
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(430.0, 42.0),
		"A / D or ← / →   MOVE        W or ↑   JUMP        J   HIT",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color("#98a4af")
	)
