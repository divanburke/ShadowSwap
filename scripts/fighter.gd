extends Node2D

# ShadowSwap - physics-driven stick fighter controller.
#
# The visible character is built from independent RigidBody2D segments joined
# by PinJoint2D constraints. Movement is produced with forces and impulses;
# pose is produced by torque drives. The torso is the main environmental
# collider while the limbs remain physical and can pass through platforms.
#
# This is an original Godot implementation inspired by the broad behavior of
# physics/procedural stick-fighter games. It does not use their assets or code.

# -------------------------------------------------------------------------
# Body proportions
# -------------------------------------------------------------------------

const TORSO_WIDTH = 20.0
const TORSO_HEIGHT = 54.0
const HEAD_RADIUS = 10.5

const SHOULDER_OFFSET = Vector2(0.0, -16.0)
const HIP_OFFSET = Vector2(0.0, 8.0)
const HEAD_OFFSET = Vector2(0.0, -39.0)

const UPPER_ARM_LENGTH = 22.0
const FOREARM_LENGTH = 23.0
const THIGH_LENGTH = 28.0
const SHIN_LENGTH = 27.0

const LIMB_WIDTH = 5.6

# -------------------------------------------------------------------------
# Movement
# -------------------------------------------------------------------------

# These values are tuned for a floaty, momentum-heavy controller rather than
# a CharacterBody2D speed cap. Horizontal movement is force-driven.
const MOVE_SPEED = 460.0
const GROUND_ACCELERATION = 8.5
const AIR_ACCELERATION = 4.3
const GROUND_BRAKE = 7.0
const AIR_BRAKE = 1.6
const MAX_HORIZONTAL_SPEED = 760.0

const GRAVITY_SCALE_NORMAL = 1.0
const GRAVITY_SCALE_FAST_FALL = 1.65

const JUMP_SPEED = 650.0
const WALL_JUMP_HORIZONTAL_SPEED = 520.0
const WALL_JUMP_VERTICAL_SPEED = 620.0
const WALL_JUMP_REPEAT_DELAY = 0.12

const WALL_CHECK_DISTANCE = 27.0

# -------------------------------------------------------------------------
# Active-ragdoll pose drive
# -------------------------------------------------------------------------

# Torque drives are intentionally softer in the air. This lets the body
# flop, rotate and recover instead of behaving like a rigid animated sprite.
const TORSO_GROUND_STRENGTH = 1100.0
const TORSO_GROUND_DAMPING = 78.0
const TORSO_AIR_STRENGTH = 240.0
const TORSO_AIR_DAMPING = 18.0

const LIMB_GROUND_STRENGTH = 86.0
const LIMB_GROUND_DAMPING = 8.0
const LIMB_AIR_STRENGTH = 44.0
const LIMB_AIR_DAMPING = 4.5

const HEAD_STRENGTH = 45.0
const HEAD_DAMPING = 6.0

const WALK_SWING = deg_to_rad(24.0)
const WALK_CYCLE_SPEED = 7.0

# The resting elbow stays bent. During an uppercut the forearm remains on
# the opposite side of the upper arm at the same relative angle.
const ELBOW_BEND = deg_to_rad(35.0)

const ATTACK_DURATION = 0.30
const ATTACK_COOLDOWN = 0.30
const UPPERCUT_START_ANGLE = deg_to_rad(52.0)
const UPPERCUT_END_ANGLE = deg_to_rad(-70.0)
const UPPERCUT_TORQUE = 110.0
const UPPERCUT_FOREARM_TORQUE = 75.0

# -------------------------------------------------------------------------
# Rendering
# -------------------------------------------------------------------------

const MINT_GREEN = Color("#67e6bc")

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

var parts: Dictionary = {}

var spawn_position = Vector2.ZERO
var facing = 1.0

var grounded = false
var wall_side = 0.0

var walk_phase = 0.0

var jump_was_down = false
var jump_consumed = false
var wall_jump_timer = 0.0

var crouching = false

var attack_timer = 0.0
var attack_cooldown = 0.0


func setup(start_position):
	spawn_position = start_position

	# Keep the controller node fixed at the world origin. The actual physics
	# pieces own their world-space motion so a moving parent never overrides
	# RigidBody2D transforms.
	position = Vector2.ZERO

	build_ragdoll(start_position)
	queue_redraw()


func build_ragdoll(start_position):
	# Clean rebuild protection.
	for child in get_children():
		child.queue_free()

	parts.clear()

	var material = PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0

	# Main collision body. Only this and the head collide with the level.
	var torso_position = start_position

	var torso = create_capsule(
		"Torso",
		TORSO_HEIGHT,
		TORSO_WIDTH,
		3.2,
		torso_position,
		0.0,
		true,
		material
	)

	torso.angular_damp = 2.0
	torso.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	var head = create_circle(
		"Head",
		HEAD_RADIUS,
		0.75,
		start_position + HEAD_OFFSET,
		true,
		material
	)

	# Limbs are real rigid bodies with inertia, but do not collide with the
	# level. This keeps them floppy instead of letting toes snag on platforms.
	var shoulder = torso_position + SHOULDER_OFFSET
	var hip = torso_position + HIP_OFFSET

	var right_upper_dir = Vector2.RIGHT.rotated(deg_to_rad(54.0))
	var left_upper_dir = Vector2.RIGHT.rotated(deg_to_rad(126.0))

	var right_elbow = shoulder + right_upper_dir * UPPER_ARM_LENGTH
	var left_elbow = shoulder + left_upper_dir * UPPER_ARM_LENGTH

	var right_forearm_dir = right_upper_dir.rotated(ELBOW_BEND)
	var left_forearm_dir = left_upper_dir.rotated(-ELBOW_BEND)

	var right_hand = right_elbow + right_forearm_dir * FOREARM_LENGTH
	var left_hand = left_elbow + left_forearm_dir * FOREARM_LENGTH

	var right_upper = create_segment(
		"RightUpperArm",
		UPPER_ARM_LENGTH,
		LIMB_WIDTH,
		0.45,
		midpoint(shoulder, right_elbow),
		right_upper_dir.angle(),
		material
	)

	var left_upper = create_segment(
		"LeftUpperArm",
		UPPER_ARM_LENGTH,
		LIMB_WIDTH,
		0.45,
		midpoint(shoulder, left_elbow),
		left_upper_dir.angle(),
		material
	)

	var right_forearm = create_segment(
		"RightForearm",
		FOREARM_LENGTH,
		LIMB_WIDTH,
		0.40,
		midpoint(right_elbow, right_hand),
		right_forearm_dir.angle(),
		material
	)

	var left_forearm = create_segment(
		"LeftForearm",
		FOREARM_LENGTH,
		LIMB_WIDTH,
		0.40,
		midpoint(left_elbow, left_hand),
		left_forearm_dir.angle(),
		material
	)

	var right_ankle = hip + Vector2(13.0, 35.0)
	var left_ankle = hip + Vector2(-13.0, 35.0)

	var right_knee = solve_initial_leg_joint(
		hip,
		right_ankle,
		1.0
	)

	var left_knee = solve_initial_leg_joint(
		hip,
		left_ankle,
		-1.0
	)

	var right_thigh_dir = (right_knee - hip).normalized()
	var left_thigh_dir = (left_knee - hip).normalized()

	var right_shin_dir = (right_ankle - right_knee).normalized()
	var left_shin_dir = (left_ankle - left_knee).normalized()

	var right_thigh = create_segment(
		"RightThigh",
		THIGH_LENGTH,
		LIMB_WIDTH,
		0.70,
		midpoint(hip, right_knee),
		right_thigh_dir.angle(),
		material
	)

	var left_thigh = create_segment(
		"LeftThigh",
		THIGH_LENGTH,
		LIMB_WIDTH,
		0.70,
		midpoint(hip, left_knee),
		left_thigh_dir.angle(),
		material
	)

	var right_shin = create_segment(
		"RightShin",
		SHIN_LENGTH,
		LIMB_WIDTH,
		0.55,
		midpoint(right_knee, right_ankle),
		right_shin_dir.angle(),
		material
	)

	var left_shin = create_segment(
		"LeftShin",
		SHIN_LENGTH,
		LIMB_WIDTH,
		0.55,
		midpoint(left_knee, left_ankle),
		left_shin_dir.angle(),
		material
	)

	# Legs interact with the floor so the feet cannot simply pass through it.
	for key in [
		"RightThigh",
		"LeftThigh",
		"RightShin",
		"LeftShin"
	]:
		parts[key].collision_layer = 2
		parts[key].collision_mask = 1

	# Add joints after all bodies exist so their paths are valid.
	make_pin_joint(
		torso,
		head,
		torso_position + Vector2(0.0, -TORSO_HEIGHT * 0.5 + 2.0),
		0.0
	)

	make_pin_joint(torso, right_upper, shoulder, 0.0)
	make_pin_joint(torso, left_upper, shoulder, 0.0)

	make_pin_joint(right_upper, right_forearm, right_elbow, 0.0)
	make_pin_joint(left_upper, left_forearm, left_elbow, 0.0)

	make_pin_joint(torso, right_thigh, hip, 0.0)
	make_pin_joint(torso, left_thigh, hip, 0.0)

	make_pin_joint(right_thigh, right_shin, right_knee, 0.0)
	make_pin_joint(left_thigh, left_shin, left_knee, 0.0)

	# Store endpoint geometry for rendering.
	parts["RightArmShoulder"] = shoulder
	parts["LeftArmShoulder"] = shoulder
	parts["RightArmElbow"] = right_elbow
	parts["LeftArmElbow"] = left_elbow
	parts["RightHandRest"] = right_hand
	parts["LeftHandRest"] = left_hand

	# Keep the limbs awake. Sleeping can make active ragdolls feel sticky.
	for key in [
		"Torso",
		"Head",
		"RightUpperArm",
		"LeftUpperArm",
		"RightForearm",
		"LeftForearm",
		"RightThigh",
		"LeftThigh",
		"RightShin",
		"LeftShin"
	]:
		var body = parts[key]
		body.can_sleep = false

	# The torso is the main contact sensor for floor/wall movement.
	torso.contact_monitor = true
	torso.max_contacts_reported = 8

	# Force one initial wake after all joints are connected.
	for key in parts:
		if parts[key] is RigidBody2D:
			parts[key].sleeping = false


func create_capsule(
	node_name,
	height,
	width,
	mass,
	world_position,
	world_angle,
	collides_with_level,
	material
):
	var body = RigidBody2D.new()
	body.name = node_name
	body.mass = mass
	body.gravity_scale = GRAVITY_SCALE_NORMAL
	body.linear_damp = 0.05
	body.angular_damp = 0.7
	body.position = world_position
	body.rotation = world_angle

	if collides_with_level:
		body.collision_layer = 2
		body.collision_mask = 1
	else:
		body.collision_layer = 0
		body.collision_mask = 0

	body.physics_material_override = material

	var collision = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = width * 0.5
	shape.height = height
	collision.shape = shape

	body.add_child(collision)
	add_child(body)

	parts[node_name] = body
	return body


func create_circle(
	node_name,
	radius,
	mass,
	world_position,
	collides_with_level,
	material
):
	var body = RigidBody2D.new()
	body.name = node_name
	body.mass = mass
	body.gravity_scale = GRAVITY_SCALE_NORMAL
	body.linear_damp = 0.05
	body.angular_damp = 0.7
	body.position = world_position

	if collides_with_level:
		body.collision_layer = 2
		body.collision_mask = 1
	else:
		body.collision_layer = 0
		body.collision_mask = 0

	body.physics_material_override = material

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape

	body.add_child(collision)
	add_child(body)

	parts[node_name] = body
	return body


func create_segment(
	node_name,
	length,
	width,
	mass,
	world_position,
	world_angle,
	material
):
	var body = RigidBody2D.new()
	body.name = node_name
	body.mass = mass
	body.gravity_scale = GRAVITY_SCALE_NORMAL
	body.linear_damp = 0.02
	body.angular_damp = 0.45
	body.position = world_position
	body.rotation = world_angle
	body.collision_layer = 0
	body.collision_mask = 0
	body.physics_material_override = material

	var collision = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = width * 0.5
	shape.height = length
	collision.shape = shape
	# CapsuleShape2D is vertical by default; rotate the local shape so its
	# long axis follows body.rotation, which stores the segment's world angle.
	collision.rotation = -PI * 0.5

	body.add_child(collision)
	add_child(body)

	parts[node_name] = body
	return body


func make_pin_joint(body_a, body_b, world_position, joint_softness):
	var joint = PinJoint2D.new()
	joint.global_position = world_position
	add_child(joint)

	# All physics pieces are siblings under this controller. Resolve paths
	# from the joint itself so the constraint always points at the intended
	# bodies.
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.softness = joint_softness
	joint.disable_collision = true


func _physics_process(delta):
	if not parts.has("Torso"):
		return

	read_input()
	update_environment_state()
	update_movement(delta)
	update_pose_drive(delta)
	update_attack_timers(delta)

	if parts["Torso"].global_position.y > 1000.0:
		respawn()

	queue_redraw()


func read_input():
	var move_direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_direction -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_direction += 1.0

	if move_direction != 0.0:
		facing = move_direction

	var jump_down = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)

	if jump_down and not jump_was_down:
		try_jump()

	jump_was_down = jump_down

	crouching = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)

	if Input.is_key_pressed(KEY_J) and attack_cooldown <= 0.0:
		start_attack()


func update_environment_state():
	grounded = detect_grounded()
	wall_side = detect_wall_side()

	if grounded:
		jump_consumed = false


func update_movement(delta):
	var torso = parts["Torso"]

	var desired_speed = 0.0

	if not crouching:
		desired_speed = facing * MOVE_SPEED
	elif grounded:
		desired_speed = facing * MOVE_SPEED * 0.45

	var acceleration = GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	var braking = GROUND_BRAKE if grounded else AIR_BRAKE

	if absf(desired_speed) > 0.0:
		var velocity_error = desired_speed - torso.linear_velocity.x
		var force = velocity_error * torso.mass * acceleration
		torso.apply_central_force(Vector2(force, 0.0))
	else:
		var braking_force = -torso.linear_velocity.x * torso.mass * braking
		torso.apply_central_force(Vector2(braking_force, 0.0))

	# Avoid an artificial hard speed cap. Instead, smoothly push back when
	# momentum gets excessive, preserving the game's loose physics feel.
	if absf(torso.linear_velocity.x) > MAX_HORIZONTAL_SPEED:
		var excess = absf(torso.linear_velocity.x) - MAX_HORIZONTAL_SPEED
		var correction = sign(torso.linear_velocity.x) * excess * torso.mass * 3.0
		torso.apply_central_force(Vector2(-correction, 0.0))

	# Fast fall is an additional force instead of a direct velocity change.
	var desired_gravity = GRAVITY_SCALE_FAST_FALL if crouching else GRAVITY_SCALE_NORMAL
	for key in parts:
		var body = parts[key]
		if body is RigidBody2D:
			body.gravity_scale = desired_gravity


func try_jump():
	if grounded:
		apply_character_velocity_change(Vector2(0.0, -JUMP_SPEED))
		return

	if wall_side != 0.0 and wall_jump_timer <= 0.0:
		var wall_jump_velocity = Vector2(
			-wall_side * WALL_JUMP_HORIZONTAL_SPEED,
			-WALL_JUMP_VERTICAL_SPEED
		)
		apply_character_velocity_change(wall_jump_velocity)
		wall_jump_timer = WALL_JUMP_REPEAT_DELAY


func apply_character_velocity_change(delta_velocity):
	for key in parts:
		var body = parts[key]

		if body is RigidBody2D:
			body.apply_central_impulse(
				delta_velocity * body.mass
			)
			body.sleeping = false


func detect_grounded():
	var torso = parts["Torso"]
	var origin = torso.global_position + Vector2(0.0, 15.0)
	var target = origin + Vector2(0.0, 16.0)

	var result = raycast(origin, target)

	return not result.is_empty()


func detect_wall_side():
	var torso = parts["Torso"]
	var origin = torso.global_position

	var left_result = raycast(
		origin,
		origin + Vector2(-WALL_CHECK_DISTANCE, 0.0)
	)

	if not left_result.is_empty():
		return -1.0

	var right_result = raycast(
		origin,
		origin + Vector2(WALL_CHECK_DISTANCE, 0.0)
	)

	if not right_result.is_empty():
		return 1.0

	return 0.0


func raycast(origin, target):
	var query = PhysicsRayQueryParameters2D.create(
		origin,
		target
	)

	query.collision_mask = 1
	query.collide_with_bodies = true
	query.exclude = get_all_body_rids()

	return get_world_2d().direct_space_state.intersect_ray(query)


func get_all_body_rids():
	var exclusions = []

	for key in parts:
		var body = parts[key]

		if body is RigidBody2D:
			exclusions.append(body.get_rid())

	return exclusions


func update_pose_drive(delta):
	var torso = parts["Torso"]
	var speed_ratio = clampf(
		absf(torso.linear_velocity.x) / MOVE_SPEED,
		0.0,
		1.0
	)

	var ground_strength = TORSO_GROUND_STRENGTH if grounded else TORSO_AIR_STRENGTH
	var ground_damping = TORSO_GROUND_DAMPING if grounded else TORSO_AIR_DAMPING

	# The torso follows the movement without becoming perfectly upright.
	var target_body_angle = -torso.linear_velocity.x * 0.00055

	if not grounded:
		target_body_angle += torso.linear_velocity.y * 0.00012

	target_body_angle = clampf(
		target_body_angle,
		deg_to_rad(-12.0),
		deg_to_rad(12.0)
	)

	drive_angle(
		torso,
		target_body_angle,
		ground_strength,
		ground_damping
	)

	# Head follows the torso with a softer drive.
	drive_angle(
		parts["Head"],
		torso.rotation,
		HEAD_STRENGTH,
		HEAD_DAMPING
	)

	if grounded and speed_ratio > 0.05:
		walk_phase = fmod(
			walk_phase + delta * (WALK_CYCLE_SPEED + speed_ratio * 4.0),
			TAU
		)
	else:
		walk_phase = move_toward(
			walk_phase,
			0.0,
			delta * 6.0
		)

	var walk_wave = sin(walk_phase) * WALK_SWING * speed_ratio

	var right_upper_target = torso.rotation + deg_to_rad(54.0) - walk_wave
	var left_upper_target = torso.rotation + deg_to_rad(126.0) + walk_wave

	var right_forearm_target = right_upper_target + ELBOW_BEND
	var left_forearm_target = left_upper_target - ELBOW_BEND

	var right_thigh_target = torso.rotation + deg_to_rad(76.0) + walk_wave * 1.15
	var left_thigh_target = torso.rotation + deg_to_rad(104.0) - walk_wave * 1.15

	var right_shin_target = torso.rotation + deg_to_rad(105.0) - walk_wave * 1.55
	var left_shin_target = torso.rotation + deg_to_rad(75.0) + walk_wave * 1.55

	if crouching and grounded:
		right_thigh_target += deg_to_rad(15.0)
		left_thigh_target -= deg_to_rad(15.0)
		right_shin_target -= deg_to_rad(20.0)
		left_shin_target += deg_to_rad(20.0)

	# Active uppercut: only the facing arm is pulled through the attack arc.
	if attack_timer > 0.0:
		var attack_progress = 1.0 - attack_timer / ATTACK_DURATION
		attack_progress = clampf(attack_progress, 0.0, 1.0)
		attack_progress = smoothstep(0.0, 1.0, attack_progress)

		var attacking_upper_angle = lerpf(
			UPPERCUT_START_ANGLE,
			UPPERCUT_END_ANGLE,
			attack_progress
		)

		if facing > 0.0:
			right_upper_target = torso.rotation + attacking_upper_angle
			right_forearm_target = right_upper_target + ELBOW_BEND
		else:
			left_upper_target = torso.rotation + PI - attacking_upper_angle
			left_forearm_target = left_upper_target - ELBOW_BEND

	var limb_strength = LIMB_GROUND_STRENGTH if grounded else LIMB_AIR_STRENGTH
	var limb_damping = LIMB_GROUND_DAMPING if grounded else LIMB_AIR_DAMPING

	drive_angle(
		parts["RightUpperArm"],
		right_upper_target,
		UPPERCUT_TORQUE if attack_timer > 0.0 and facing > 0.0 else limb_strength,
		limb_damping
	)

	drive_angle(
		parts["LeftUpperArm"],
		left_upper_target,
		UPPERCUT_TORQUE if attack_timer > 0.0 and facing < 0.0 else limb_strength,
		limb_damping
	)

	drive_angle(
		parts["RightForearm"],
		right_forearm_target,
		UPPERCUT_FOREARM_TORQUE if attack_timer > 0.0 and facing > 0.0 else limb_strength,
		limb_damping
	)

	drive_angle(
		parts["LeftForearm"],
		left_forearm_target,
		UPPERCUT_FOREARM_TORQUE if attack_timer > 0.0 and facing < 0.0 else limb_strength,
		limb_damping
	)

	drive_angle(
		parts["RightThigh"],
		right_thigh_target,
		limb_strength,
		limb_damping
	)

	drive_angle(
		parts["LeftThigh"],
		left_thigh_target,
		limb_strength,
		limb_damping
	)

	drive_angle(
		parts["RightShin"],
		right_shin_target,
		limb_strength,
		limb_damping
	)

	drive_angle(
		parts["LeftShin"],
		left_shin_target,
		limb_strength,
		limb_damping
	)

	if attack_timer <= 0.0:
		wall_jump_timer = maxf(
			wall_jump_timer - delta,
			0.0
		)
	else:
		wall_jump_timer = maxf(
			wall_jump_timer - delta,
			0.0
		)


func drive_angle(body, target_angle, strength, damping):
	var angle_error = wrapf(
		target_angle - body.rotation,
		-PI,
		PI
	)

	var torque = angle_error * strength
	torque -= body.angular_velocity * damping

	body.apply_torque(torque)


func update_attack_timers(delta):
	if attack_timer > 0.0:
		attack_timer = maxf(
			attack_timer - delta,
			0.0
		)

	if attack_cooldown > 0.0:
		attack_cooldown = maxf(
			attack_cooldown - delta,
			0.0
		)


func start_attack():
	attack_timer = ATTACK_DURATION
	attack_cooldown = ATTACK_COOLDOWN


func respawn():
	for key in parts:
		var body = parts[key]

		if body is RigidBody2D:
			body.freeze = true

	await get_tree().physics_frame

	build_ragdoll(spawn_position)
	queue_redraw()


func solve_initial_leg_joint(hip, ankle, bend_direction):
	var to_ankle = ankle - hip
	var distance = to_ankle.length()

	var max_reach = THIGH_LENGTH + SHIN_LENGTH
	var min_reach = absf(THIGH_LENGTH - SHIN_LENGTH)
	var solved_distance = clampf(
		distance,
		min_reach + 0.001,
		max_reach - 0.001
	)

	var direction = to_ankle / maxf(distance, 0.001)
	var perpendicular = Vector2(-direction.y, direction.x)

	var cos_knee = clampf(
		(
			THIGH_LENGTH * THIGH_LENGTH +
			solved_distance * solved_distance -
			SHIN_LENGTH * SHIN_LENGTH
		) / (2.0 * THIGH_LENGTH * solved_distance),
		-1.0,
		1.0
	)

	var along = THIGH_LENGTH * cos(acos(cos_knee))
	var bend = sqrt(
		maxf(
			THIGH_LENGTH * THIGH_LENGTH - along * along,
			0.0
		)
	)

	var candidate_a = hip + direction * along + perpendicular * bend
	var candidate_b = hip + direction * along - perpendicular * bend

	if candidate_a.x * bend_direction > candidate_b.x * bend_direction:
		return candidate_a

	return candidate_b


func midpoint(a, b):
	return (a + b) * 0.5


func segment_endpoints(body, length):
	var direction = Vector2.RIGHT.rotated(body.rotation)
	return [
		body.global_position - direction * length * 0.5,
		body.global_position + direction * length * 0.5
	]


func _draw():
	if not parts.has("Torso"):
		return

	var color = MINT_GREEN

	draw_vertical_segment(
		parts["Torso"],
		TORSO_HEIGHT,
		TORSO_WIDTH * 0.46,
		color
	)

	draw_segment(
		parts["RightUpperArm"],
		UPPER_ARM_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["RightForearm"],
		FOREARM_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["LeftUpperArm"],
		UPPER_ARM_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["LeftForearm"],
		FOREARM_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["RightThigh"],
		THIGH_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["RightShin"],
		SHIN_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["LeftThigh"],
		THIGH_LENGTH,
		LIMB_WIDTH,
		color
	)

	draw_segment(
		parts["LeftShin"],
		SHIN_LENGTH,
		LIMB_WIDTH,
		color
	)

	var head = to_local(parts["Head"].global_position)
	draw_circle(
		head,
		HEAD_RADIUS,
		color
	)

	# Small joint caps keep the articulated silhouette visually connected.
	for joint_name in [
		"RightUpperArm",
		"LeftUpperArm",
		"RightForearm",
		"LeftForearm",
		"RightThigh",
		"LeftThigh",
		"RightShin",
		"LeftShin"
	]:
		var point = to_local(parts[joint_name].global_position)
		draw_circle(
			point,
			LIMB_WIDTH * 0.58,
			color
		)


func draw_vertical_segment(body, length, width, color):
	var direction = Vector2.UP.rotated(body.rotation)
	var a = to_local(body.global_position - direction * length * 0.5)
	var b = to_local(body.global_position + direction * length * 0.5)

	draw_pill(
		a,
		b,
		width,
		color
	)


func draw_segment(body, length, width, color):
	var endpoints = segment_endpoints(body, length)
	var a = to_local(endpoints[0])
	var b = to_local(endpoints[1])

	draw_pill(
		a,
		b,
		width,
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
