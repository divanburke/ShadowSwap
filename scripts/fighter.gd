extends CharacterBody2D

# ShadowSwap - simple one-player stick fighter foundation.
#
# The fighter uses a clean, upright stick-figure silhouette:
#   - small round head
#   - short narrow torso
#   - long proportional arms
#   - long two-bone legs
#   - simple procedural walking
#   - physics-driven limb motion
#
# The design is inspired by the broad silhouette of classic stick-fighter
# games without copying any proprietary character artwork.

const BODY_WIDTH = 28.0
const BODY_HEIGHT = 78.0

# Upright body layout.
const HEAD_RADIUS = 11.0
const HEAD_Y = -48.0
const SHOULDER_Y = -25.0
const HIP_Y = -8.0

const MOVE_SPEED = 320.0
const GROUND_ACCELERATION = 2200.0
const GROUND_DECELERATION = 2600.0
const AIR_ACCELERATION = 900.0
const AIR_DECELERATION = 420.0

const GRAVITY = 1700.0
const MAX_FALL_SPEED = 950.0
const JUMP_SPEED = 590.0

const ATTACK_DURATION = 0.30
const ATTACK_COOLDOWN = 0.30

const MINT_GREEN = Color("#67e6bc")

# -------------------------------------------------------------------------
# Arms
# -------------------------------------------------------------------------
# Arm length is tied directly to the body height. The hand position is
# calculated from the shoulder, not from the torso center, so the arm keeps
# the correct length while it swings.
const ARM_LENGTH = BODY_HEIGHT * 0.53
const UPPER_ARM_LENGTH = ARM_LENGTH * 0.52
const FOREARM_LENGTH = ARM_LENGTH * 0.48
const ARM_THICKNESS = BODY_WIDTH * 0.19
const ARM_REST_VECTOR = Vector2(-0.7220, 0.6919)
const ATTACK_REACH = ARM_LENGTH * 1.15
const UPPERCUT_ELBOW_ANGLE = deg_to_rad(35.0)

const ARM_SPRING = 16.0
const ARM_DAMPING = 3.7
const ARM_GRAVITY = 680.0

# -------------------------------------------------------------------------
# Legs
# -------------------------------------------------------------------------
# Each leg is a real visual two-bone chain:
#       hip -> knee -> ankle -> foot
#
# The longer legs and short torso make the character stand upright rather
# than looking like a squat/crouched stick figure.
const THIGH_LENGTH = BODY_HEIGHT * 0.35
const SHIN_LENGTH = BODY_HEIGHT * 0.32
const LEG_THICKNESS = BODY_WIDTH * 0.19

const ANKLE_BASE_X = BODY_WIDTH * 0.34
const ANKLE_BASE_Y = BODY_HEIGHT * 0.53
const WALK_STRIDE = BODY_HEIGHT * 0.18
const WALK_LIFT = BODY_HEIGHT * 0.11
const WALK_CYCLE_SPEED = 4.0

const PLANTED_FOOT_SPRING = 72.0
const PLANTED_FOOT_DAMPING = 11.0
const SWING_FOOT_SPRING = 48.0
const SWING_FOOT_DAMPING = 7.5

# The visible ankle has a small clearance above the collision floor so the
# floppy pose cannot visually sink through the platform.
const GROUND_RENDER_Y = BODY_HEIGHT * 0.49
const GROUND_RENDER_MARGIN = LEG_THICKNESS * 0.55

# Whole-body pose physics. The collision stays upright, but the visible
# stick figure can lean, sway and settle like a loose body.
const BODY_ANGULAR_SPRING = 18.0
const BODY_ANGULAR_DAMPING = 3.2
const BODY_MAX_ANGLE = deg_to_rad(16.0)
const BODY_ACCEL_LEAN = 0.00055
const BODY_SPEED_LEAN = 0.00085

const BODY_BOB_SPRING = 20.0
const BODY_BOB_DAMPING = 3.8
const BODY_MAX_BOB = 5.0

var facing = 1.0
var body_angle = 0.0
var body_angular_velocity = 0.0
var body_bob = 0.0
var body_bob_velocity = 0.0

var left_hand_offset = Vector2.ZERO
var right_hand_offset = Vector2.ZERO
var left_hand_velocity = Vector2.ZERO
var right_hand_velocity = Vector2.ZERO
var left_elbow_offset = Vector2.ZERO
var right_elbow_offset = Vector2.ZERO

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
	reset_limb_positions()
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


func reset_limb_positions():
	var left_rest = Vector2(
		ARM_REST_VECTOR.x * ARM_LENGTH,
		ARM_REST_VECTOR.y * ARM_LENGTH
	)

	var right_rest = Vector2(
		-ARM_REST_VECTOR.x * ARM_LENGTH,
		ARM_REST_VECTOR.y * ARM_LENGTH
	)

	left_hand_offset = Vector2(0.0, SHOULDER_Y) + left_rest
	right_hand_offset = Vector2(0.0, SHOULDER_Y) + right_rest

	left_hand_velocity = Vector2.ZERO
	right_hand_velocity = Vector2.ZERO

	left_elbow_offset = Vector2(0.0, SHOULDER_Y) + left_rest.normalized() * UPPER_ARM_LENGTH
	right_elbow_offset = Vector2(0.0, SHOULDER_Y) + right_rest.normalized() * UPPER_ARM_LENGTH

	left_knee_offset = Vector2(-3.0, HIP_Y + THIGH_LENGTH)
	right_knee_offset = Vector2(3.0, HIP_Y + THIGH_LENGTH)


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
		# Facing changes only from movement. Attacks use the last walked
		# direction, matching a simple directional stick-fighter controller.
		facing = move_direction

	var jump_down = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)

	if jump_down and not jump_was_down:
		try_jump()

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

	update_body_floppiness(
		delta,
		acceleration
	)

	# ==============================================================
	# ARMS - physical hanging/swinging motion
	# ==============================================================
	var shoulder = Vector2(0.0, SHOULDER_Y)

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

	var arm_swing = sin(walking_phase) * WALK_STRIDE * 0.55 * speed_ratio

	var left_target = shoulder + Vector2(
		ARM_REST_VECTOR.x * ARM_LENGTH - horizontal_inertia + arm_swing,
		ARM_REST_VECTOR.y * ARM_LENGTH + vertical_inertia
	)

	var right_target = shoulder + Vector2(
		-ARM_REST_VECTOR.x * ARM_LENGTH - horizontal_inertia - arm_swing,
		ARM_REST_VECTOR.y * ARM_LENGTH + vertical_inertia
	)

	left_hand_velocity.y += ARM_GRAVITY * delta
	right_hand_velocity.y += ARM_GRAVITY * delta

	if not is_on_floor():
		var air_motion = clampf(
			velocity.y / JUMP_SPEED,
			-1.0,
			1.0
		)

		left_target.y += air_motion * BODY_HEIGHT * 0.06
		right_target.y += air_motion * BODY_HEIGHT * 0.06

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

	left_hand_offset = constrain_from_anchor(
		shoulder,
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

	right_hand_offset = constrain_from_anchor(
		shoulder,
		right_arm_state[0],
		ARM_LENGTH
	)
	right_hand_velocity = right_arm_state[1]

	# Each arm is now a two-bone chain. The elbow is solved from the
	# shoulder and hand while keeping the upper/forearm lengths fixed,
	# making the joint quite rigid without adding another floppy spring.
	left_elbow_offset = solve_arm_joint(
		shoulder,
		left_hand_offset,
		1.0
	)

	right_elbow_offset = solve_arm_joint(
		shoulder,
		right_hand_offset,
		-1.0
	)

	# ==============================================================
	# LEGS - human walk cycle
	# ==============================================================
	# Each foot has two phases:
	#   0.0 -> 0.5 : planted/supporting the body
	#   0.5 -> 1.0 : lifted and swinging forward
	#
	# During support the foot moves backward relative to the hips as the
	# body passes over it. During swing it lifts, travels forward, and lands.
	if is_on_floor() and speed_ratio > 0.05:
		walking_phase = fmod(
			walking_phase + delta * (WALK_CYCLE_SPEED + speed_ratio * 5.0),
			TAU
		)
	else:
		walking_phase = move_toward(
			walking_phase,
			0.0,
			delta * 3.2
		)

	var left_cycle = fposmod(walking_phase / TAU, 1.0)
	var right_cycle = fposmod(left_cycle + 0.5, 1.0)

	var left_leg_target = get_walk_ankle_target(
		left_cycle,
		-1.0,
		is_on_floor()
	)

	var right_leg_target = get_walk_ankle_target(
		right_cycle,
		1.0,
		is_on_floor()
	)

	if speed_ratio <= 0.05 and is_on_floor():
		left_leg_target = Vector2(-ANKLE_BASE_X, ANKLE_BASE_Y)
		right_leg_target = Vector2(ANKLE_BASE_X, ANKLE_BASE_Y)

	# In the air both legs relax downward and slightly behind the body.
	if not is_on_floor():
		left_leg_target.y += BODY_HEIGHT * 0.06
		right_leg_target.y += BODY_HEIGHT * 0.06
		left_leg_target.x -= facing * BODY_HEIGHT * 0.04
		right_leg_target.x -= facing * BODY_HEIGHT * 0.04

	var left_cycle_stance = is_on_floor() and left_cycle < 0.5
	var right_cycle_stance = is_on_floor() and right_cycle < 0.5

	var left_ankle_state = spring_vector(
		left_ankle_offset,
		left_ankle_velocity,
		left_leg_target,
		PLANTED_FOOT_SPRING if left_cycle_stance else SWING_FOOT_SPRING,
		PLANTED_FOOT_DAMPING if left_cycle_stance else SWING_FOOT_DAMPING,
		delta
	)

	left_ankle_offset = left_ankle_state[0]
	left_ankle_velocity = left_ankle_state[1]

	var right_ankle_state = spring_vector(
		right_ankle_offset,
		right_ankle_velocity,
		right_leg_target,
		PLANTED_FOOT_SPRING if right_cycle_stance else SWING_FOOT_SPRING,
		PLANTED_FOOT_DAMPING if right_cycle_stance else SWING_FOOT_DAMPING,
		delta
	)

	right_ankle_offset = right_ankle_state[0]
	right_ankle_velocity = right_ankle_state[1]

	# The knee solver naturally produces a deeper bend on the lifted swing
	# leg because its ankle is higher and farther forward.
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


func get_walk_ankle_target(cycle, side, grounded):
	var forward = facing

	# Side separation keeps both legs connected to the central hip while
	# leaving enough room for a readable human silhouette.
	var side_offset = side * ANKLE_BASE_X

	if not grounded:
		return Vector2(
			side_offset - forward * BODY_HEIGHT * 0.04,
			ANKLE_BASE_Y + BODY_HEIGHT * 0.06
		)

	# Support: the foot is planted and the body moves over it.
	if cycle < 0.5:
		var support_t = cycle * 2.0
		support_t = smoothstep(0.0, 1.0, support_t)

		return Vector2(
			side_offset + lerpf(
				forward * WALK_STRIDE,
				-forward * WALK_STRIDE,
				support_t
			),
			ANKLE_BASE_Y
		)

	# Swing: lift the foot, bring it forward, then lower it for contact.
	var swing_t = (cycle - 0.5) * 2.0
	var swing_progress = smoothstep(0.0, 1.0, swing_t)
	var lift = sin(swing_t * PI) * WALK_LIFT

	return Vector2(
		side_offset + lerpf(
			-forward * WALK_STRIDE,
			forward * WALK_STRIDE,
			swing_progress
		),
		ANKLE_BASE_Y - lift
	)


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

	# Select the knee that bends slightly forward.
	if candidate_a.x * bend_direction > candidate_b.x * bend_direction:
		return candidate_a

	return candidate_b


func update_body_floppiness(delta, acceleration):
	# Forward acceleration tips the body backward; braking lets it swing
	# forward and settle instead of snapping straight.
	var target_angle = clampf(
		-velocity.x * BODY_SPEED_LEAN -
		acceleration.x * BODY_ACCEL_LEAN,
		-BODY_MAX_ANGLE,
		BODY_MAX_ANGLE
	)

	# Jumping and falling add a small amount of whole-body sway.
	if not is_on_floor():
		target_angle += clampf(
			velocity.y * 0.00028,
			-deg_to_rad(5.0),
			deg_to_rad(5.0)
		)

	var angle_acceleration = (
		target_angle - body_angle
	) * BODY_ANGULAR_SPRING
	angle_acceleration -= body_angular_velocity * BODY_ANGULAR_DAMPING

	body_angular_velocity += angle_acceleration * delta
	body_angle += body_angular_velocity * delta
	body_angle = clampf(
		body_angle,
		-BODY_MAX_ANGLE * 1.15,
		BODY_MAX_ANGLE * 1.15
	)

	# Soft vertical compression/extension makes the torso react to movement
	# and landings instead of remaining visually rigid.
	var target_bob = 0.0

	if is_on_floor():
		target_bob = clampf(
			absf(velocity.x) * 0.012,
			0.0,
			BODY_MAX_BOB
		)

		if not previous_floor_state:
			body_bob_velocity -= 26.0

	var bob_acceleration = (
		target_bob - body_bob
	) * BODY_BOB_SPRING
	bob_acceleration -= body_bob_velocity * BODY_BOB_DAMPING

	body_bob_velocity += bob_acceleration * delta
	body_bob += body_bob_velocity * delta
	body_bob = clampf(
		body_bob,
		-BODY_MAX_BOB,
		BODY_MAX_BOB
	)


func pose_point(point):
	var pivot = Vector2(0.0, HIP_Y)
	var relative = point - pivot
	relative = relative.rotated(body_angle)

	return pivot + relative + Vector2(0.0, body_bob)


func solve_arm_joint(shoulder, hand, bend_direction):
	var to_hand = hand - shoulder
	var distance = to_hand.length()

	if distance < 0.001:
		return shoulder + Vector2(UPPER_ARM_LENGTH * bend_direction, 0.0)

	var max_reach = UPPER_ARM_LENGTH + FOREARM_LENGTH
	var min_reach = absf(UPPER_ARM_LENGTH - FOREARM_LENGTH)

	var solved_distance = clampf(
		distance,
		min_reach + 0.001,
		max_reach - 0.001
	)

	var direction = to_hand / distance
	var perpendicular = Vector2(-direction.y, direction.x)

	var cos_elbow = clampf(
		(
			UPPER_ARM_LENGTH * UPPER_ARM_LENGTH +
			solved_distance * solved_distance -
			FOREARM_LENGTH * FOREARM_LENGTH
		) / (2.0 * UPPER_ARM_LENGTH * solved_distance),
		-1.0,
		1.0
	)

	var along = UPPER_ARM_LENGTH * cos(acos(cos_elbow))
	var bend = sqrt(
		maxf(
			UPPER_ARM_LENGTH * UPPER_ARM_LENGTH -
			along * along,
			0.0
		)
	)

	var candidate_a = shoulder + direction * along + perpendicular * bend
	var candidate_b = shoulder + direction * along - perpendicular * bend

	if candidate_a.x * bend_direction > candidate_b.x * bend_direction:
		return candidate_a

	return candidate_b


func spring_vector(current, current_velocity, target, stiffness, damping, delta):
	var acceleration = (target - current) * stiffness
	acceleration -= current_velocity * damping

	current_velocity += acceleration * delta
	current += current_velocity * delta

	return [current, current_velocity]


func constrain_from_anchor(anchor, point, length):
	var relative = point - anchor

	if relative.length_squared() < 0.001:
		return anchor + Vector2(length, 0.0)

	return anchor + relative.normalized() * length


func constrain_ankle_to_floor(point):
	var posed = pose_point(point)

	if is_on_floor():
		var maximum_y = GROUND_RENDER_Y - GROUND_RENDER_MARGIN
		posed.y = minf(posed.y, maximum_y)

	return posed


func get_uppercut_pose(attack_progress):
	var progress = smoothstep(0.0, 1.0, attack_progress)

	# The upper arm does the entire swing. The forearm is locked to it
	# at a fixed 35 degree relative angle, so it never moves independently.
	var upper_arm_angle = lerpf(
		deg_to_rad(60.0),
		deg_to_rad(-60.0),
		progress
	)

	var upper_direction = Vector2(
		facing * cos(upper_arm_angle),
		sin(upper_arm_angle)
	)

	# Bend the forearm to the opposite side of the upper arm,
	# while keeping the same fixed 35 degree joint angle.
	var forearm_direction = upper_direction.rotated(
		-UPPERCUT_ELBOW_ANGLE * facing
	)

	var shoulder = Vector2(0.0, SHOULDER_Y)
	var elbow = shoulder + upper_direction * UPPER_ARM_LENGTH
	var hand = elbow + forearm_direction * FOREARM_LENGTH

	return [elbow, hand]


func get_point(name):
	var attack_progress = 0.0

	if attack_timer > 0.0:
		attack_progress = 1.0 - attack_timer / ATTACK_DURATION
		attack_progress = clampf(attack_progress, 0.0, 1.0)

	match name:
		"head":
			return pose_point(Vector2(0.0, HEAD_Y))

		"shoulder_left":
			return pose_point(Vector2(0.0, SHOULDER_Y))

		"shoulder_right":
			return pose_point(Vector2(0.0, SHOULDER_Y))

		"hand_left":
			if attack_timer > 0.0 and facing < 0.0:
				var left_attack_pose = get_uppercut_pose(attack_progress)
				return pose_point(left_attack_pose[1])

			return pose_point(left_hand_offset)

		"hand_right":
			if attack_timer > 0.0 and facing > 0.0:
				var right_attack_pose = get_uppercut_pose(attack_progress)
				return pose_point(right_attack_pose[1])

			return pose_point(right_hand_offset)

		"elbow_left":
			if attack_timer > 0.0 and facing < 0.0:
				var left_attack_pose = get_uppercut_pose(attack_progress)
				return pose_point(left_attack_pose[0])

			return pose_point(left_elbow_offset)

		"elbow_right":
			if attack_timer > 0.0 and facing > 0.0:
				var right_attack_pose = get_uppercut_pose(attack_progress)
				return pose_point(right_attack_pose[0])

			return pose_point(right_elbow_offset)

		"left_hip":
			return pose_point(Vector2(0.0, HIP_Y))

		"right_hip":
			return pose_point(Vector2(0.0, HIP_Y))

		"left_knee":
			return pose_point(left_knee_offset)

		"right_knee":
			return pose_point(right_knee_offset)

		"left_ankle":
			return constrain_ankle_to_floor(left_ankle_offset)

		"right_ankle":
			return constrain_ankle_to_floor(right_ankle_offset)

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

	var elbow_left = get_point("elbow_left")
	var elbow_right = get_point("elbow_right")

	# Limbs first, torso second. Each arm is split at a rigid elbow joint.
	draw_pill(
		shoulder_left,
		elbow_left,
		ARM_THICKNESS,
		color
	)

	draw_pill(
		elbow_left,
		hand_left,
		ARM_THICKNESS,
		color
	)

	draw_pill(
		shoulder_right,
		elbow_right,
		ARM_THICKNESS,
		color
	)

	draw_pill(
		elbow_right,
		hand_right,
		ARM_THICKNESS,
		color
	)

	draw_circle(
		elbow_left,
		ARM_THICKNESS * 0.62,
		color
	)

	draw_circle(
		elbow_right,
		ARM_THICKNESS * 0.62,
		color
	)

	# Long, simple two-bone legs.
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

	# Legs end cleanly at the ankles. There are no separate feet.
	# Short, narrow upright torso.
	draw_pill(
		pose_point(Vector2(0.0, SHOULDER_Y - 3.0)),
		pose_point(Vector2(0.0, HIP_Y)),
		BODY_WIDTH * 0.46,
		color
	)

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
