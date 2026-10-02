extends CharacterBody2D

# ShadowSwap - simple one-player stick fighter foundation.
#
# This version intentionally has only:
#   - one player
#   - one solid-color body
#   - movement
#   - jumping
#   - a human-like procedural walk cycle
#   - physics-driven arm swing
#   - a directional arm hit
#
# No AI, weapons, ragdolls, damage systems, rounds, or extra combat systems.

const BODY_WIDTH = 28.0
const BODY_HEIGHT = 78.0

const HEAD_RADIUS = BODY_HEIGHT * 0.18
const SHOULDER_Y = -BODY_HEIGHT * 0.32
const HIP_Y = BODY_HEIGHT * 0.205

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

# -------------------------------------------------------------------------
# Human-proportioned arms
# -------------------------------------------------------------------------
# Arm length is derived from the body height instead of being a fixed
# pixel value, so the proportions stay consistent if the fighter is resized.
const ARM_LENGTH = BODY_HEIGHT * 0.52
const ARM_THICKNESS = BODY_WIDTH * 0.285
const ARM_REST_X = ARM_LENGTH * 0.70
const ARM_REST_Y = ARM_LENGTH * 0.714

const ARM_SPRING = 24.0
const ARM_DAMPING = 5.2
const ARM_GRAVITY = 620.0
const ATTACK_REACH = ARM_LENGTH * 1.12

# -------------------------------------------------------------------------
# Human-like legs
# -------------------------------------------------------------------------
# A real leg is treated as two connected bones: thigh + shin. We solve the
# knee position from a desired ankle position with a two-bone IK calculation.
const THIGH_LENGTH = BODY_HEIGHT * 0.36
const SHIN_LENGTH = BODY_HEIGHT * 0.35
const LEG_THICKNESS = BODY_WIDTH * 0.30

const ANKLE_BASE_X = BODY_WIDTH * 0.36
const ANKLE_BASE_Y = BODY_HEIGHT * 0.63
const WALK_STRIDE = BODY_HEIGHT * 0.17
const WALK_LIFT = BODY_HEIGHT * 0.085
const WALK_FOOT_FORWARD = BODY_HEIGHT * 0.09

const FOOT_SPRING = 58.0
const FOOT_DAMPING = 9.0

var facing = 1.0

var left_hand_offset = Vector2(-ARM_REST_X, ARM_REST_Y)
var right_hand_offset = Vector2(ARM_REST_X, ARM_REST_Y)
var left_hand_velocity = Vector2.ZERO
var right_hand_velocity = Vector2.ZERO

var left_ankle_offset = Vector2(-ANKLE_BASE_X, ANKLE_BASE_Y)
var right_ankle_offset = Vector2(ANKLE_BASE_X, ANKLE_BASE_Y)
var left_ankle_velocity = Vector2.ZERO
var right_ankle_velocity = Vector2.ZERO

var left_knee_offset = Vector2.ZERO
var right_knee_offset = Vector2.ZERO

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

	# ==============================================================
	# ARMS
	# ==============================================================
	# The hand is a spring-driven point with gravity and body inertia.
	# Its distance from the shoulder is constrained to the proportional
	# arm length after the spring step.
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
		-ARM_REST_X - horizontal_inertia,
		ARM_REST_Y + vertical_inertia
	)

	var right_target = Vector2(
		ARM_REST_X - horizontal_inertia,
		ARM_REST_Y + vertical_inertia
	)

	left_hand_velocity.y += ARM_GRAVITY * delta
	right_hand_velocity.y += ARM_GRAVITY * delta

	if not is_on_floor():
		var air_motion = clampf(
			velocity.y / JUMP_SPEED,
			-1.0,
			1.0
		)

		left_target.y += air_motion * BODY_HEIGHT * 0.065
		right_target.y += air_motion * BODY_HEIGHT * 0.065

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

	left_hand_offset = keep_length(
		left_arm_state[0],
		ARM_LENGTH
	)

	left_hand_velocity = left_arm_state[1]

	var right_arm_state = spring_vector(
		right_hand_offset,
		right_hand_velocity,
		right_target,
		ARM_SPRING,
		ARM_DAMPING,
		delta
	)

	right_hand_offset = keep_length(
		right_arm_state[0],
		ARM_LENGTH
	)

	right_hand_velocity = right_arm_state[1]

	# ==============================================================
	# LEGS
	# ==============================================================
	# Phase 0 / PI are opposite legs. The foot moves forward during its
	# swing phase and rises from the floor, while the other foot stays low.
	if is_on_floor() and speed_ratio > 0.05:
		walking_phase += delta * (4.5 + speed_ratio * 9.0)
	else:
		walking_phase = move_toward(
			walking_phase,
			0.0,
			delta * 2.8
		)

	var left_step = sin(walking_phase)
	var right_step = sin(walking_phase + PI)

	var left_lift = maxf(left_step, 0.0) * WALK_LIFT
	var right_lift = maxf(right_step, 0.0) * WALK_LIFT

	var left_ankle_target = Vector2(
		-ANKLE_BASE_X + left_step * WALK_STRIDE,
		ANKLE_BASE_Y - left_lift
	)

	var right_ankle_target = Vector2(
		ANKLE_BASE_X + right_step * WALK_STRIDE,
		ANKLE_BASE_Y - right_lift
	)

	# When stationary, keep both feet planted and slightly separated.
	if speed_ratio <= 0.05 and is_on_floor():
		left_ankle_target = Vector2(-ANKLE_BASE_X, ANKLE_BASE_Y)
		right_ankle_target = Vector2(ANKLE_BASE_X, ANKLE_BASE_Y)

	# Airborne legs tuck slightly instead of continuing to walk.
	if not is_on_floor():
		left_ankle_target.y += BODY_HEIGHT * 0.055
		right_ankle_target.y += BODY_HEIGHT * 0.055
		left_ankle_target.x -= facing * BODY_HEIGHT * 0.05
		right_ankle_target.x -= facing * BODY_HEIGHT * 0.05

	var left_ankle_state = spring_vector(
		left_ankle_offset,
		left_ankle_velocity,
		left_ankle_target,
		FOOT_SPRING,
		FOOT_DAMPING,
		delta
	)

	left_ankle_offset = left_ankle_state[0]
	left_ankle_velocity = left_ankle_state[1]

	var right_ankle_state = spring_vector(
		right_ankle_offset,
		right_ankle_velocity,
		right_ankle_target,
		FOOT_SPRING,
		FOOT_DAMPING,
		delta
	)

	right_ankle_offset = right_ankle_state[0]
	right_ankle_velocity = right_ankle_state[1]

	# Solve each leg as a proper two-bone chain.
	left_knee_offset = solve_leg(
		Vector2(0.0, HIP_Y),
		left_ankle_offset,
		facing
	)

	right_knee_offset = solve_leg(
		Vector2(0.0, HIP_Y),
		right_ankle_offset,
		facing
	)

	previous_floor_state = is_on_floor()


func solve_leg(hip, ankle, bend_direction):
	var to_ankle = ankle - hip
	var distance = to_ankle.length()

	if distance < 0.001:
		return hip + Vector2(0.0, THIGH_LENGTH)

	var max_reach = THIGH_LENGTH + SHIN_LENGTH
	var min_reach = absf(THIGH_LENGTH - SHIN_LENGTH)

	distance = clampf(
		distance,
		min_reach + 0.001,
		max_reach - 0.001
	)

	var direction = to_ankle / to_ankle.length()
	var perpendicular = Vector2(
		-direction.y,
		direction.x
	)

	var cos_knee_angle = clampf(
		(
			THIGH_LENGTH * THIGH_LENGTH +
			distance * distance -
			SHIN_LENGTH * SHIN_LENGTH
		) / (2.0 * THIGH_LENGTH * distance),
		-1.0,
		1.0
	)

	var knee_along = THIGH_LENGTH * cos(acos(cos_knee_angle))
	var knee_height = sqrt(
		maxf(
			THIGH_LENGTH * THIGH_LENGTH -
			knee_along * knee_along,
			0.0
		)
	)

	var candidate_a = hip + direction * knee_along + perpendicular * knee_height
	var candidate_b = hip + direction * knee_along - perpendicular * knee_height

	# Pick the solution whose knee points in the direction the fighter faces.
	# This gives the familiar forward-bending human knee.
	if candidate_a.x * bend_direction > candidate_b.x * bend_direction:
		return candidate_a

	return candidate_b


func spring_vector(current, current_velocity, target, stiffness, damping, delta):
	var acceleration = (target - current) * stiffness
	acceleration -= current_velocity * damping

	current_velocity += acceleration * delta
	current += current_velocity * delta

	return [current, current_velocity]


func keep_length(point, length):
	if point.length_squared() < 0.001:
		return Vector2(length, 0.0)

	return point.normalized() * length


func get_point(name):
	var attack_progress = 0.0

	if attack_timer > 0.0:
		attack_progress = 1.0 - attack_timer / ATTACK_DURATION
		attack_progress = clampf(attack_progress, 0.0, 1.0)

	var punch = sin(attack_progress * PI)

	match name:
		"head":
			return Vector2(0.0, -BODY_HEIGHT * 0.615)

		"shoulder_left":
			return Vector2(0.0, SHOULDER_Y)

		"shoulder_right":
			return Vector2(0.0, SHOULDER_Y)

		"hand_left":
			if attack_timer > 0.0 and facing < 0.0:
				return Vector2(
					-ATTACK_REACH * punch,
					-BODY_HEIGHT * 0.23
				)

			return left_hand_offset

		"hand_right":
			if attack_timer > 0.0 and facing > 0.0:
				return Vector2(
					ATTACK_REACH * punch,
					-BODY_HEIGHT * 0.23
				)

			return right_hand_offset

		"left_hip":
			return Vector2(0.0, HIP_Y)

		"right_hip":
			return Vector2(0.0, HIP_Y)

		"left_knee":
			return left_knee_offset

		"right_knee":
			return right_knee_offset

		"left_ankle":
			return left_ankle_offset

		"right_ankle":
			return right_ankle_offset

		"left_foot":
			return left_ankle_offset + Vector2(
				facing * WALK_FOOT_FORWARD,
				0.0
			)

		"right_foot":
			return right_ankle_offset + Vector2(
				facing * WALK_FOOT_FORWARD,
				0.0
			)

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
	var left_knee = get_point("left_knee")
	var right_knee = get_point("right_knee")
	var left_ankle = get_point("left_ankle")
	var right_ankle = get_point("right_ankle")
	var left_foot = get_point("left_foot")
	var right_foot = get_point("right_foot")

	# Arms are single continuous pills, with no artificial elbow joints.
	draw_pill(
		shoulder_left,
		hand_left,
		ARM_THICKNESS,
		color
	)

	draw_pill(
		shoulder_right,
		hand_right,
		ARM_THICKNESS,
		color
	)

	# Each leg now has a real thigh + shin chain. The two segments share the
	# same centerline at the knee, keeping the joint clean without a separate
	# oversized knee ball.
	draw_pill(
		left_hip,
		left_knee,
		LEG_THICKNESS,
		color
	)

	draw_pill(
		left_knee,
		left_ankle,
		LEG_THICKNESS,
		color
	)

	draw_pill(
		right_hip,
		right_knee,
		LEG_THICKNESS,
		color
	)

	draw_pill(
		right_knee,
		right_ankle,
		LEG_THICKNESS,
		color
	)

	# Small feet give the lower legs a clear planted direction.
	draw_pill(
		left_ankle,
		left_foot,
		LEG_THICKNESS,
		color
	)

	draw_pill(
		right_ankle,
		right_foot,
		LEG_THICKNESS,
		color
	)

	# Torso covers the upper limb roots, keeping shoulders and hips centered
	# exactly on the body's vertical axis.
	draw_pill(
		Vector2(0.0, SHOULDER_Y - 5.0),
		Vector2(0.0, HIP_Y),
		BODY_WIDTH * 0.39,
		color
	)

	# Head.
	draw_circle(
		head,
		HEAD_RADIUS,
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
