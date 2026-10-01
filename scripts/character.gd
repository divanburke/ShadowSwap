extends CharacterBody2D
class_name SwapCharacter

const VIEW_SIZE := Vector2(1152.0, 648.0)
const BODY_SIZE := Vector2(28.0, 42.0)

const MOVE_SPEED := 285.0
const MOVE_ACCEL := 1900.0
const MOVE_FRICTION := 2300.0
const GRAVITY := 1500.0
const JUMP_SPEED := 560.0

const REAL_WORLD_MASK := 1
const SHADOW_WORLD_MASK := 2
const PLAYER_LAYER := 4
const SHADOW_LAYER := 8

var owner_game: Node
var is_shadow := false
var world_id := 1
var body_color := Color.WHITE
var accent_color := Color.WHITE
var character_name := "REAL"

func setup(
	game: Node,
	shadow_character: bool,
	start_position: Vector2,
	start_world: int,
	p_body_color: Color,
	p_accent_color: Color,
	p_character_name: String
) -> void:
	owner_game = game
	is_shadow = shadow_character
	world_id = start_world
	body_color = p_body_color
	accent_color = p_accent_color
	character_name = p_character_name

	position = start_position
	collision_layer = SHADOW_LAYER if is_shadow else PLAYER_LAYER
	set_world(world_id)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = BODY_SIZE
	shape.shape = rectangle
	add_child(shape)

	queue_redraw()

func set_world(new_world: int) -> void:
	world_id = new_world
	collision_mask = SHADOW_WORLD_MASK if world_id == 2 else REAL_WORLD_MASK
	queue_redraw()

func _physics_process(delta: float) -> void:
	if owner_game == null:
		return

	if owner_game.game_won:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)
		move_and_slide()
		queue_redraw()
		return

	var is_active := owner_game.active_character == self
	var direction := 0.0

	if is_active:
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
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			MOVE_FRICTION * delta
		)

	if is_active and Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = -JUMP_SPEED

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()
	position.x = clampf(position.x, 18.0, VIEW_SIZE.x - 18.0)

	if position.y > VIEW_SIZE.y + 80.0:
		owner_game.respawn_pair()

	queue_redraw()

func _draw() -> void:
	var half := BODY_SIZE * 0.5
	var rect := Rect2(-half, BODY_SIZE)

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
