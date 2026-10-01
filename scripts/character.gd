extends CharacterBody2D

const BODY_SIZE = Vector2(28, 42)
const VIEW_SIZE = Vector2(1152, 648)

const REAL_WORLD = 1
const SHADOW_WORLD = 2
const REAL_MASK = 1
const SHADOW_MASK = 2

const MOVE_SPEED = 285.0
const MOVE_ACCEL = 1900.0
const MOVE_FRICTION = 2300.0
const GRAVITY = 1500.0
const JUMP_SPEED = 560.0

var owner_game
var is_shadow = false
var world_id = 1
var body_color = Color.WHITE
var accent_color = Color.WHITE
var character_name = "REAL"


func setup(game, shadow_character, start_position, start_world, p_body_color, p_accent_color, p_name):
	owner_game = game
	is_shadow = shadow_character
	world_id = start_world
	body_color = p_body_color
	accent_color = p_accent_color
	character_name = p_name

	position = start_position

	if is_shadow:
		collision_layer = 8
	else:
		collision_layer = 4

	set_world(world_id)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = BODY_SIZE
	collision.shape = shape
	add_child(collision)

	queue_redraw()


func set_world(new_world):
	world_id = new_world

	if world_id == SHADOW_WORLD:
		collision_mask = SHADOW_MASK
	else:
		collision_mask = REAL_MASK

	queue_redraw()


func _physics_process(delta):
	if owner_game == null:
		return

	if bool(owner_game.get("game_won")):
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)
		move_and_slide()
		queue_redraw()
		return

	var active = owner_game.get("active_character") == self
	var direction = 0.0

	if active:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction += 1.0

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * MOVE_SPEED, MOVE_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_FRICTION * delta)

	if active and (Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = -JUMP_SPEED

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()

	position.x = clampf(position.x, 18.0, VIEW_SIZE.x - 18.0)

	if position.y > VIEW_SIZE.y + 80.0:
		owner_game.call("reset_level")

	queue_redraw()


func _draw():
	var half = BODY_SIZE / 2.0
	var rect = Rect2(-half, BODY_SIZE)

	if is_shadow:
		draw_circle(Vector2.ZERO, 25.0, Color(accent_color, 0.10))
		draw_circle(Vector2.ZERO, 20.0, Color(accent_color, 0.16))
		draw_rect(rect, Color(body_color, 0.78), true)
		draw_rect(rect, accent_color, false, 2.0)
		draw_circle(Vector2(-6, -5), 2.5, Color(1, 1, 1, 0.7))
		draw_circle(Vector2(6, -5), 2.5, Color(1, 1, 1, 0.7))
		draw_line(Vector2(-7, 7), Vector2(7, 7), Color(accent_color, 0.8), 2.0)
	else:
		draw_circle(Vector2.ZERO, 26.0, Color(accent_color, 0.09))
		draw_rect(rect, body_color, true)
		draw_rect(rect, accent_color, false, 2.0)
		draw_circle(Vector2(-6, -5), 2.5, accent_color)
		draw_circle(Vector2(6, -5), 2.5, accent_color)
		draw_line(Vector2(-7, 7), Vector2(7, 7), accent_color, 2.0)
