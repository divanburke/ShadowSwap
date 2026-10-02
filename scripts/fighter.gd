extends CharacterBody2D

# ShadowSwap - simple one-player stick fighter foundation.
#
# This version intentionally has only:
#   - one player
#   - one solid-color body
#   - movement
#   - jumping
#   - a small walking animation
#   - a directional arm hit
#
# No AI, weapons, ragdolls, damage systems, rounds, or extra combat systems.

const BODY_WIDTH = 28.0
const BODY_HEIGHT = 78.0

const MOVE_SPEED = 320.0
const GROUND_ACCELERATION = 2200.0
const GROUND_DECELERATION = 2600.0
const AIR_ACCELERATION = 900.0
const AIR_DECELERATION = 420.0

const GRAVITY = 1700.0
const MAX_FALL_SPEED = 950.0
const JUMP_SPEED = 590.0

const ATTACK_DURATION = 0.18
const ATTACK_COOLDOWN = 0.26

const MINT_GREEN = Color("#67e6bc")

var facing = 1.0
var walking_phase = 0.0
var attack_timer = 0.0
var attack_cooldown = 0.0
var jump_was_down = false


func setup(start_position):
	global_position = start_position

	collision_layer = 2
	collision_mask = 3

	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_stop_on_slope = true
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.08

	build_collision()
	queue_redraw()


func build_collision():
	var collision = CollisionShape2D.new()
	collision.name = "BodyCollision"

	var capsule = CapsuleShape2D.new()
	capsule.radius = BODY_WIDTH * 0.5
	capsule.height = BODY_HEIGHT

	collision.shape = capsule
	collision.position = Vector2(0.0, 2.0)

	add_child(collision)


func _physics_process(delta):
	read_input()
	update_movement(delta)
	update_animation(delta)

	if attack_timer > 0.0:
		attack_timer = maxf(attack_timer - delta, 0.0)

	if attack_cooldown > 0.0:
		attack_cooldown = maxf(attack_cooldown - delta, 0.0)

	queue_redraw()


func read_input():
	var move_direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_direction -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_direction += 1.0

	if move_direction != 0.0:
		# Facing changes only from movement, so an attack always uses the
		# direction the player last walked.
		facing = move_direction

	var jump_down = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)

	if jump_down and not jump_was_down:
		try_jump()

	# Releasing jump early gives a shorter jump.
	if not jump_down and jump_was_down and velocity.y < -180.0:
		velocity.y *= 0.48

	if Input.is_key_pressed(KEY_J) and attack_cooldown <= 0.0:
		start_attack()

	jump_was_down = jump_down


func update_movement(delta):
	var move_direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_direction -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_direction += 1.0

	var on_floor = is_on_floor()

	if move_direction != 0.0:
		var acceleration = GROUND_ACCELERATION

		if not on_floor:
			acceleration = AIR_ACCELERATION

		velocity.x = move_toward(
			velocity.x,
			move_direction * MOVE_SPEED,
			acceleration * delta
		)
	else:
		var deceleration = GROUND_DECELERATION

		if not on_floor:
			deceleration = AIR_DECELERATION

		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

	if not on_floor:
		velocity.y += GRAVITY * delta

	velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	move_and_slide()

	if is_on_floor() and absf(velocity.x) < 2.0:
		velocity.x = 0.0


func try_jump():
	if is_on_floor():
		velocity.y = -JUMP_SPEED


func start_attack():
	attack_timer = ATTACK_DURATION
	attack_cooldown = ATTACK_COOLDOWN


func update_animation(delta):
	var speed_ratio = clampf(absf(velocity.x) / MOVE_SPEED, 0.0, 1.0)

	if is_on_floor() and speed_ratio > 0.05:
		# Faster movement produces a faster but still controlled gait.
		walking_phase += delta * (5.5 + speed_ratio * 10.0)


func get_point(name):
	# One shared gait value drives the entire body. This is important:
	# the arms and legs move as one connected human-like walk cycle.
	var stride = sin(walking_phase) * 11.0 * facing
	var opposite_stride = -stride

	# Lift the swinging leg while the planted leg stays low.
	var left_lift = maxf(stride / 11.0, 0.0) * 6.0
	var right_lift = maxf(opposite_stride / 11.0, 0.0) * 6.0

	# Knees move less than the feet, producing a natural bent-leg gait.
	var left_knee = Vector2(
		-5.0 + stride * 0.48,
		24.0 - left_lift
	)

	var right_knee = Vector2(
		5.0 + opposite_stride * 0.48,
		24.0 - right_lift
	)

	var left_foot = Vector2(
		-5.0 + stride,
		49.0 - left_lift
	)

	var right_foot = Vector2(
		5.0 + opposite_stride,
		49.0 - right_lift
	)

	# Human walking uses opposite arm/leg timing.
	var arm_stride = stride * 0.72

	var left_elbow = Vector2(
		-10.0 - arm_stride * 0.45,
		-13.0
	)

	var right_elbow = Vector2(
		10.0 + arm_stride * 0.45,
		-13.0
	)

	var left_hand = Vector2(
		-19.0 - arm_stride,
		-1.0
	)

	var right_hand = Vector2(
		19.0 + arm_stride,
		-1.0
	)

	# Attack extends only the arm on the side of the last movement direction.
	var attack_progress = 0.0

	if attack_timer > 0.0:
		attack_progress = 1.0 - attack_timer / ATTACK_DURATION
		attack_progress = clampf(attack_progress, 0.0, 1.0)

	# Smooth punch-out and return.
	var punch = sin(attack_progress * PI)

	if attack_timer > 0.0:
		if facing > 0.0:
			right_elbow = Vector2(15.0 + 8.0 * punch, -20.0)
			right_hand = Vector2(25.0 + 34.0 * punch, -21.0)
		else:
			left_elbow = Vector2(-15.0 - 8.0 * punch, -20.0)
			left_hand = Vector2(-25.0 - 34.0 * punch, -21.0)

	var body_bob = 0.0

	if is_on_floor() and absf(velocity.x) > 18.0:
		body_bob = -absf(sin(walking_phase)) * 1.4

	match name:
		"head":
			return Vector2(0.0, -48.0 + body_bob)

		"shoulder_left":
			return Vector2(-9.0, -25.0 + body_bob)

		"shoulder_right":
			return Vector2(9.0, -25.0 + body_bob)

		"elbow_left":
			return left_elbow + Vector2(0.0, body_bob)

		"elbow_right":
			return right_elbow + Vector2(0.0, body_bob)

		"hand_left":
			return left_hand + Vector2(0.0, body_bob)

		"hand_right":
			return right_hand + Vector2(0.0, body_bob)

		"left_hip":
			return Vector2(-5.0, 16.0 + body_bob)

		"right_hip":
			return Vector2(5.0, 16.0 + body_bob)

		"left_knee":
			return left_knee + Vector2(0.0, body_bob)

		"right_knee":
			return right_knee + Vector2(0.0, body_bob)

		"left_foot":
			return left_foot + Vector2(0.0, body_bob)

		"right_foot":
			return right_foot + Vector2(0.0, body_bob)

	return Vector2.ZERO


func _draw():
	var color = MINT_GREEN

	var head = get_point("head")
	var shoulder_left = get_point("shoulder_left")
	var shoulder_right = get_point("shoulder_right")
	var elbow_left = get_point("elbow_left")
	var elbow_right = get_point("elbow_right")
	var hand_left = get_point("hand_left")
	var hand_right = get_point("hand_right")

	var left_hip = get_point("left_hip")
	var right_hip = get_point("right_hip")
	var left_knee = get_point("left_knee")
	var right_knee = get_point("right_knee")
	var left_foot = get_point("left_foot")
	var right_foot = get_point("right_foot")

	# Head.
	draw_circle(
		head,
		14.0,
		color
	)

	# Rounded torso.
	draw_pill(
		Vector2(0.0, -30.0),
		Vector2(0.0, 16.0),
		11.0,
		color
	)

	# Two-segment arms with rounded joints.
	draw_pill(
		shoulder_left,
		elbow_left,
		7.0,
		color
	)

	draw_pill(
		elbow_left,
		hand_left,
		7.0,
		color
	)

	draw_pill(
		shoulder_right,
		elbow_right,
		7.0,
		color
	)

	draw_pill(
		elbow_right,
		hand_right,
		7.0,
		color
	)

	# Two-segment legs. The upper-leg starts exactly on the hip point.
	draw_pill(
		left_hip,
		left_knee,
		8.0,
		color
	)

	draw_pill(
		left_knee,
		left_foot,
		8.0,
		color
	)

	draw_pill(
		right_hip,
		right_knee,
		8.0,
		color
	)

	draw_pill(
		right_knee,
		right_foot,
		8.0,
		color
	)


func draw_pill(a, b, width, color):
	var radius = width * 0.5

	draw_line(
		a,
		b,
		color,
		width,
		true
	)

	draw_circle(
		a,
		radius,
		color
	)

	draw_circle(
		b,
		radius,
		color
	)
