extends CharacterBody2D

const BODY_SIZE = Vector2(28, 42)
const VIEW_SIZE = Vector2(1152, 648)

const REAL_WORLD = 1
const SHADOW_WORLD = 2
const REAL_MASK = 1
const SHADOW_MASK = 2

const MOVE_SPEED = 300.0
const MOVE_ACCEL = 2200.0
const MOVE_FRICTION = 2600.0
const GRAVITY = 1550.0
const JUMP_SPEED = 590.0
const COYOTE_TIME = 0.10

var owner_game
var is_shadow = false
var world_id = REAL_WORLD
var body_color = Color.WHITE
var accent_color = Color.WHITE
var character_name = "REAL"

var coyote_timer = 0.0
var jump_was_down = false
var facing = 1.0
var animation_time = 0.0


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

	floor_snap_length = 7.0
	floor_max_angle = deg_to_rad(48.0)

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
		velocity.x = move_toward(velocity.x, 0.0, MOVE_FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		queue_redraw()
		return

	var active = owner_game.get("active_character") == self

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	var direction = 0.0

	if active:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction += 1.0

	if direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			direction * MOVE_SPEED,
			MOVE_ACCEL * delta
		)
		facing = sign(direction)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			MOVE_FRICTION * delta
		)

	var jump_down = Input.is_key_pressed(KEY_SPACE)
	var jump_pressed = jump_down and not jump_was_down
	jump_was_down = jump_down

	if active and jump_pressed and coyote_timer > 0.0:
		velocity.y = -JUMP_SPEED
		coyote_timer = 0.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()

	position.x = clampf(position.x, 18.0, VIEW_SIZE.x - 18.0)

	if position.y > VIEW_SIZE.y + 90.0:
		owner_game.call_deferred("player_hit", "FELL INTO THE VOID")

	animation_time += delta
	queue_redraw()


func _draw():
	var half = BODY_SIZE / 2.0
	var bob = 0.0

	if is_on_floor() and absf(velocity.x) > 20.0:
		bob = sin(animation_time * 16.0) * 1.2

	var rect = Rect2(
		Vector2(-half.x, -half.y + bob),
		BODY_SIZE
	)

	var glow_alpha = 0.10
	if owner_game != null and owner_game.get("active_character") == self:
		glow_alpha = 0.18

	draw_circle(Vector2.ZERO, 25.0, Color(accent_color, glow_alpha))

	if is_shadow:
		draw_circle(Vector2(0, 19), 17.0, Color(0.05, 0.04, 0.09, 0.7))
		draw_rect(rect, Color(body_color, 0.78), true)
		draw_rect(rect, accent_color, false, 2.0)
		draw_circle(Vector2(-6, -5 + bob), 2.4, Color(1, 1, 1, 0.7))
		draw_circle(Vector2(6, -5 + bob), 2.4, Color(1, 1, 1, 0.7))
		draw_line(
			Vector2(-7, 7 + bob),
			Vector2(7, 7 + bob),
			Color(accent_color, 0.85),
			2.0
		)
	else:
		draw_circle(Vector2(0, 19), 17.0, Color(0.02, 0.03, 0.05, 0.6))
		draw_rect(rect, body_color, true)
		draw_rect(rect, accent_color, false, 2.0)
		draw_circle(Vector2(-6, -5 + bob), 2.4, accent_color)
		draw_circle(Vector2(6, -5 + bob), 2.4, accent_color)
		draw_line(
			Vector2(-7, 7 + bob),
			Vector2(7, 7 + bob),
			accent_color,
			2.0
		)
