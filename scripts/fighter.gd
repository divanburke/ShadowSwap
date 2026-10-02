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

# Arms behave like lightweight masses hanging from the shoulders.
# Walking acceleration, jumping and gravity all influence their motion.
const ARM_SPRING = 24.0
const ARM_DAMPING = 5.2
const ARM_GRAVITY = 620.0

# Feet use a gentle procedural gait because a simple two-foot walk cycle is
# much more stable and readable than trying to balance physical leg bodies.
const FOOT_SPRING = 50.0
const FOOT_DAMPING = 8.5
const WALK_STRIDE = 10.0
const WALK_LIFT = 4.0

var facing = 1.0

var left_hand_offset = Vector2(-22.0, -3.0)
var right_hand_offset = Vector2(22.0, -3.0)
var left_hand_velocity = Vector2.ZERO
var right_hand_velocity = Vector2.ZERO

var left_foot_offset = Vector2(-12.0, 49.0)
var right_foot_offset = Vector2(12.0, 49.0)
var left_foot_velocity = Vector2.ZERO
var right_foot_velocity = Vector2.ZERO

var walking_phase = 0.0
var previous_velocity = Vector2.ZERO
var previous_floor_state = false

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
	update_limb_physics(delta)

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


func update_limb_physics(delta):
	var speed_ratio = clampf(
		absf(velocity.x) / MOVE_SPEED,
		0.0,
		1.0
	)

	var acceleration = Vector2.ZERO

	if delta > 0.0:
		acceleration = (velocity - previous_velocity) / delta

	previous_velocity = velocity

	# --------------------------------------------------------------
	# ARMS: spring + gravity + real body acceleration.
	# --------------------------------------------------------------
	# The shoulders stay fixed. The hands are allowed to lag behind the
	# body, fall under gravity, and swing when the body changes velocity.
	var horizontal_inertia = clampf(
		acceleration.x * 0.012,
		-10.0,
		10.0
	)

	var vertical_inertia = clampf(
		acceleration.y * 0.008,
		-7.0,
		7.0
	)

	var left_target = Vector2(
		-22.0 - horizontal_inertia,
		-3.0 + vertical_inertia
	)

	var right_target = Vector2(
		22.0 - horizontal_inertia,
		-3.0 + vertical_inertia
	)

	# Gravity makes the arms naturally drop while airborne instead of
	# snapping to an animation pose.
	left_hand_velocity.y += ARM_GRAVITY * delta
	right_hand_velocity.y += ARM_GRAVITY * delta

	# Jumping pushes both arms upward slightly, falling lets them trail down.
	if not is_on_floor():
		var air_angle = clampf(
			velocity.y / JUMP_SPEED,
			-1.0,
			1.0
		)

		left_target.y += air_angle * 5.0
		right_target.y += air_angle * 5.0

	# A landing gives both arms a small physical swing.
	if is_on_floor() and not previous_floor_state:
		left_hand_velocity.y -= 100.0
		right_hand_velocity.y -= 100.0

	var left_arm_state = spring_vector(
		left_hand_offset,
		left_hand_velocity,
		left_target,
		ARM_SPRING,
		ARM_DAMPING,
		delta
	)

	left_hand_offset = left_arm_state[0]
	left_hand_velocity = left_arm_state[1]

	var right_arm_state = spring_vector(
		right_hand_offset,
		right_hand_velocity,
		right_target,
		ARM_SPRING,
		ARM_DAMPING,
		delta
	)

	right_hand_offset = right_arm_state[0]
	right_hand_velocity = right_arm_state[1]

	# --------------------------------------------------------------
	# LEGS: simple human two-step walking gait.
	# --------------------------------------------------------------
	if is_on_floor() and speed_ratio > 0.05:
		walking_phase += delta * (5.0 + speed_ratio * 10.0)
	else:
		walking_phase = move_toward(
			walking_phase,
			0.0,
			delta * 2.5
		)

	var step_a = sin(walking_phase) * WALK_STRIDE
	var step_b = sin(walking_phase + PI) * WALK_STRIDE

	var lift_a = maxf(
		sin(walking_phase),
		0.0
	) * WALK_LIFT

	var lift_b = maxf(
		sin(walking_phase + PI),
		0.0
	) * WALK_LIFT

	var left_foot_target = Vector2(
		-12.0 + step_a,
		49.0 - lift_a
	)

	var right_foot_target = Vector2(
		12.0 + step_b,
		49.0 - lift_b
	)

	if not is_on_floor():
		left_foot_target.y += 4.0
		right_foot_target.y += 4.0

	var left_foot_state = spring_vector(
		left_foot_offset,
		left_foot_velocity,
		left_foot_target,
		FOOT_SPRING,
		FOOT_DAMPING,
		delta
	)

	left_foot_offset = left_foot_state[0]
	left_foot_velocity = left_foot_state[1]

	var right_foot_state = spring_vector(
		right_foot_offset,
		right_foot_velocity,
		right_foot_target,
		FOOT_SPRING,
		FOOT_DAMPING,
		delta
	)

	right_foot_offset = right_foot_state[0]
	right_foot_velocity = right_foot_state[1]

	previous_floor_state = is_on_floor()


func spring_vector(current, current_velocity, target, stiffness, damping, delta):
	var acceleration = (target - current) * stiffness
	acceleration -= current_velocity * damping

	current_velocity += acceleration * delta
	current += current_velocity * delta

	return [current, current_velocity]


func get_point(name):
	var attack_progress = 0.0

	if attack_timer > 0.0:
		attack_progress = 1.0 - attack_timer / ATTACK_DURATION
		attack_progress = clampf(attack_progress, 0.0, 1.0)

	var punch = sin(attack_progress * PI)

	match name:
		"head":
			return Vector2(0.0, -48.0)

		"shoulder_left":
			return Vector2(0.0, -25.0)

		"shoulder_right":
			return Vector2(0.0, -25.0)

		"hand_left":
			if attack_timer > 0.0 and facing < 0.0:
				return Vector2(
					-44.0 * punch,
					-22.0
				)

			return left_hand_offset

		"hand_right":
			if attack_timer > 0.0 and facing > 0.0:
				return Vector2(
					44.0 * punch,
					-22.0
				)

			return right_hand_offset

		"left_hip":
			return Vector2(0.0, 16.0)

		"right_hip":
			return Vector2(0.0, 16.0)

		"left_foot":
			return left_foot_offset

		"right_foot":
			return right_foot_offset

	return Vector2.ZERO


func _draw():
	var color = MINT_GREEN

	var head = get_point("head")
	var shoulder_left = get_point("shoulder_left")
	var shoulder_right = get_point("shoulder_right")
	var hand_left = get_point("hand_left")
	var hand_right = get_point("hand_right")
	var left_hip = get_point("left_hip")
	var right_hip = get_point("right_hip")
	var left_foot = get_point("left_foot")
	var right_foot = get_point("right_foot")

	# Limbs are drawn first. The torso then covers their roots, preventing
	# bumps or blobs at the shoulder and hip connections.
	draw_pill(
		shoulder_left,
		hand_left,
		8.0,
		color
	)

	draw_pill(
		shoulder_right,
		hand_right,
		8.0,
		color
	)

	draw_pill(
		left_hip,
		left_foot,
		9.0,
		color
	)

	draw_pill(
		right_hip,
		right_foot,
		9.0,
		color
	)

	# Torso covers the upper ends of the limbs.
	draw_pill(
		Vector2(0.0, -30.0),
		Vector2(0.0, 16.0),
		11.0,
		color
	)

	# Head.
	draw_circle(
		head,
		14.0,
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
