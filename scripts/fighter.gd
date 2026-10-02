extends Node2D

# ShadowSwap - active-ragdoll stick fighter.
#
# The five physics layers are now combined in one system:
# 1. Whole-body momentum / floppy torso.
# 2. Spring-driven limbs with physical joints.
# 3. Human-like locomotion driven by forces.
# 4. Physics-based punch / hit impulse handling.
# 5. Real RigidBody2D ragdoll parts joined together with PinJoint2D.
#
# The controller does NOT directly teleport the body parts. It steers them
# with forces and torques, so collisions can disturb the pose and the body
# can recover from that disturbance.

const BODY_WIDTH := 22.0
const BODY_HEIGHT := 72.0
const HEAD_RADIUS := 11.0
const HEAD_Y := -46.0
const SHOULDER_Y := -22.0
const HIP_Y := -5.0

const MOVE_SPEED := 320.0
const MOVE_FORCE := 2100.0
const AIR_MOVE_FORCE := 850.0
const BRAKE_FORCE := 1500.0
const GRAVITY := 1700.0
const MAX_FALL_SPEED := 950.0
const JUMP_IMPULSE := 520.0

const ARM_LENGTH := BODY_HEIGHT * 0.62
const ARM_THICKNESS := 4.0
const LEG_THICKNESS := 4.5
const THIGH_LENGTH := BODY_HEIGHT * 0.34
const SHIN_LENGTH := BODY_HEIGHT * 0.31

const ARM_SPRING := 90.0
const ARM_DAMPING := 16.0
const LEG_SPRING := 180.0
const LEG_DAMPING := 24.0
const BODY_UPRIGHT_SPRING := 180.0
const BODY_UPRIGHT_DAMPING := 22.0
const HEAD_SPRING := 100.0
const HEAD_DAMPING := 16.0

const WALK_SPEED := 7.0
const WALK_STRIDE := 17.0
const WALK_LIFT := 10.0
const WALK_FORCE := 150.0

const ATTACK_DURATION := 0.32
const ATTACK_COOLDOWN := 0.45
const ATTACK_REACH := ARM_LENGTH * 1.22
const ATTACK_FORCE := 1150.0
const ATTACK_BODY_TORQUE := 95.0
const ATTACK_HIT_RADIUS := 24.0

const FLOOR_Y := 572.0
const GROUND_EPSILON := 5.0

const MINT_GREEN := Color("#67e6bc")
const MINT_LIMB := Color("#55d8ad")
const MINT_DARK := Color("#48b995")

var facing := 1.0
var walk_phase := 0.0
var attack_timer := 0.0
var attack_cooldown := 0.0
var jump_was_down := false

var spawn_position := Vector2.ZERO
var torso: RigidBody2D
var head: RigidBody2D
var upper_arm_l: RigidBody2D
var lower_arm_l: RigidBody2D
var upper_arm_r: RigidBody2D
var lower_arm_r: RigidBody2D
var upper_leg_l: RigidBody2D
var lower_leg_l: RigidBody2D
var upper_leg_r: RigidBody2D
var lower_leg_r: RigidBody2D

var ragdoll_parts: Array[RigidBody2D] = []
var joints: Array[PinJoint2D] = []
var initialized := false
var was_grounded := false


func setup(start_position: Vector2):
	spawn_position = start_position
	position = Vector2.ZERO
	build_ragdoll()
	initialized = true
	queue_redraw()


func build_ragdoll():
	# Build the physical skeleton around the requested spawn point.
	torso = make_capsule(
		"Torso",
		spawn_position + Vector2(0.0, 0.0),
		BODY_WIDTH * 0.34,
		BODY_HEIGHT - 4.0,
		3.0
	)

	head = make_circle(
		"Head",
		spawn_position + Vector2(0.0, HEAD_Y),
		HEAD_RADIUS,
		0.9
	)

	var shoulder = spawn_position + Vector2(0.0, SHOULDER_Y)
	var hip = spawn_position + Vector2(0.0, HIP_Y)

	var arm_upper_len := ARM_LENGTH * 0.48
	var arm_lower_len := ARM_LENGTH * 0.52

	upper_arm_l = make_capsule(
		"UpperArmL",
		shoulder + Vector2(-arm_upper_len * 0.18, arm_upper_len * 0.52),
		ARM_THICKNESS * 0.5,
		arm_upper_len,
		0.65
	)
	lower_arm_l = make_capsule(
		"LowerArmL",
		shoulder + Vector2(-arm_upper_len * 0.52, arm_upper_len + arm_lower_len * 0.50),
		ARM_THICKNESS * 0.5,
		arm_lower_len,
		0.55
	)

	upper_arm_r = make_capsule(
		"UpperArmR",
		shoulder + Vector2(arm_upper_len * 0.18, arm_upper_len * 0.52),
		ARM_THICKNESS * 0.5,
		arm_upper_len,
		0.65
	)
	lower_arm_r = make_capsule(
		"LowerArmR",
		shoulder + Vector2(arm_upper_len * 0.52, arm_upper_len + arm_lower_len * 0.50),
		ARM_THICKNESS * 0.5,
		arm_lower_len,
		0.55
	)

	upper_leg_l = make_capsule(
		"UpperLegL",
		hip + Vector2(-7.0, THIGH_LENGTH * 0.5),
		LEG_THICKNESS * 0.5,
		THIGH_LENGTH,
		1.1
	)
	lower_leg_l = make_capsule(
		"LowerLegL",
		hip + Vector2(-7.0, THIGH_LENGTH + SHIN_LENGTH * 0.5),
		LEG_THICKNESS * 0.5,
		SHIN_LENGTH,
		0.95
	)

	upper_leg_r = make_capsule(
		"UpperLegR",
		hip + Vector2(7.0, THIGH_LENGTH * 0.5),
		LEG_THICKNESS * 0.5,
		THIGH_LENGTH,
		1.1
	)
	lower_leg_r = make_capsule(
		"LowerLegR",
		hip + Vector2(7.0, THIGH_LENGTH + SHIN_LENGTH * 0.5),
		LEG_THICKNESS * 0.5,
		SHIN_LENGTH,
		0.95
	)

	# Start the limbs with the same loose pose used by the target springs.
	upper_arm_l.rotation = -0.10
	lower_arm_l.rotation = -0.04
	upper_arm_r.rotation = 0.10
	lower_arm_r.rotation = 0.04

	upper_leg_l.rotation = -0.04
	lower_leg_l.rotation = 0.02
	upper_leg_r.rotation = 0.04
	lower_leg_r.rotation = -0.02

	ragdoll_parts = [
		torso,
		head,
		upper_arm_l,
		lower_arm_l,
		upper_arm_r,
		lower_arm_r,
		upper_leg_l,
		lower_leg_l,
		upper_leg_r,
		lower_leg_r
	]

	# Pin joints keep the skeleton connected while allowing every segment to
	# rotate freely. The springs below are what actively animate the pose.
	connect_pin(torso, head, spawn_position + Vector2(0.0, HEAD_Y + HEAD_RADIUS * 0.55))
	connect_pin(torso, upper_arm_l, shoulder)
	connect_pin(upper_arm_l, lower_arm_l, get_initial_joint(upper_arm_l, lower_arm_l))
	connect_pin(torso, upper_arm_r, shoulder)
	connect_pin(upper_arm_r, lower_arm_r, get_initial_joint(upper_arm_r, lower_arm_r))

	connect_pin(torso, upper_leg_l, hip + Vector2(-2.0, 0.0))
	connect_pin(upper_leg_l, lower_leg_l, get_initial_joint(upper_leg_l, lower_leg_l))
	connect_pin(torso, upper_leg_r, hip + Vector2(2.0, 0.0))
	connect_pin(upper_leg_r, lower_leg_r, get_initial_joint(upper_leg_r, lower_leg_r))

	for part in ragdoll_parts:
		part.collision_layer = 2
		part.collision_mask = 1
		part.contact_monitor = true
		part.max_contacts_reported = 4
		part.linear_damp = 0.45
		part.angular_damp = 3.5
		part.gravity_scale = 1.0

	# Make the torso the main controlled mass. Limbs remain physically simulated.
	torso.linear_damp = 0.7
	torso.angular_damp = 4.5


func make_capsule(
	part_name: String,
	world_position: Vector2,
	radius: float,
	height: float,
	mass: float
) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = part_name
	body.position = world_position
	body.mass = mass
	body.freeze = false
	body.lock_rotation = false

	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	collision.shape = shape
	body.add_child(collision)

	add_child(body)

	var visual := SegmentVisual.new()
	var visual_color := MINT_GREEN if part_name == "Torso" else MINT_LIMB
	visual.setup(height - radius * 2.0, radius, visual_color)
	body.add_child(visual)

	return body


func make_circle(
	part_name: String,
	world_position: Vector2,
	radius: float,
	mass: float
) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = part_name
	body.position = world_position
	body.mass = mass
	body.freeze = false
	body.lock_rotation = false

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)

	add_child(body)

	var visual := CircleVisual.new()
	visual.setup(radius, MINT_GREEN)
	body.add_child(visual)

	return body


func connect_pin(a: RigidBody2D, b: RigidBody2D, anchor: Vector2):
	var joint := PinJoint2D.new()
	joint.name = a.name + "_" + b.name + "_Joint"
	joint.position = anchor
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()
	joint.softness = 0.0
	joint.angular_limit_enabled = true
	joint.angular_limit_lower = -0.65
	joint.angular_limit_upper = 0.65
	add_child(joint)
	joints.append(joint)


func get_initial_joint(a: RigidBody2D, b: RigidBody2D) -> Vector2:
	# The midpoint between the two starting bodies is a stable approximation
	# of their anatomical joint.
	return (a.global_position + b.global_position) * 0.5


func _physics_process(delta: float):
	if not initialized:
		return

	read_input()
	update_controller(delta)
	update_ragdoll_pose(delta)
	update_attack(delta)

	if attack_timer > 0.0:
		attack_timer = maxf(attack_timer - delta, 0.0)

	if attack_cooldown > 0.0:
		attack_cooldown = maxf(attack_cooldown - delta, 0.0)

	queue_redraw()


func read_input():
	var direction := 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	if direction != 0.0:
		facing = direction

	var jump_down := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if jump_down and not jump_was_down:
		try_jump()

	if Input.is_key_pressed(KEY_J) and attack_cooldown <= 0.0:
		start_attack()

	jump_was_down = jump_down


func update_controller(delta: float):
	var grounded := is_grounded()

	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	var desired_speed := direction * MOVE_SPEED
	var horizontal_error := desired_speed - torso.linear_velocity.x

	if direction != 0.0:
		var force := MOVE_FORCE if grounded else AIR_MOVE_FORCE
		torso.apply_central_force(Vector2(
			clampf(horizontal_error * force * 0.018, -force, force),
			0.0
		))
	else:
		var brake := BRAKE_FORCE if grounded else BRAKE_FORCE * 0.25
		torso.apply_central_force(Vector2(
			clampf(-torso.linear_velocity.x * brake * 0.02, -brake, brake),
			0.0
		))

	if torso.linear_velocity.y > MAX_FALL_SPEED:
		torso.linear_velocity.y = MAX_FALL_SPEED

	# Keep the root body from slowly drifting horizontally forever.
	if grounded and direction == 0.0 and absf(torso.linear_velocity.x) < 5.0:
		torso.linear_velocity.x = 0.0

	was_grounded = grounded


func try_jump():
	if is_grounded():
		torso.apply_central_impulse(Vector2(0.0, -JUMP_IMPULSE))

		# A small upward impulse to the lower body keeps the jump readable
		# without making the legs behave like rigid sticks.
		upper_leg_l.apply_central_impulse(Vector2(0.0, -JUMP_IMPULSE * 0.10))
		upper_leg_r.apply_central_impulse(Vector2(0.0, -JUMP_IMPULSE * 0.10))


func is_grounded() -> bool:
	var feet := [
		lower_leg_l,
		lower_leg_r,
		upper_leg_l,
		upper_leg_r
	]

	for part in feet:
		if part == null:
			continue

		if part.global_position.y > FLOOR_Y - BODY_HEIGHT * 0.55:
			return true

	return torso.global_position.y >= spawn_position.y + 5.0 and torso.linear_velocity.y >= -30.0


func update_ragdoll_pose(delta: float):
	var grounded := is_grounded()
	var speed := torso.linear_velocity.x

	if grounded and absf(speed) > 18.0:
		walk_phase = fmod(walk_phase + delta * WALK_SPEED * (0.8 + absf(speed) / MOVE_SPEED), TAU)
	else:
		walk_phase = move_toward(walk_phase, 0.0, delta * 4.0)

	# --------------------------------------------------------------
	# Torso: active upright spring with momentum.
	# --------------------------------------------------------------
	var target_torso_angle := clampf(
		-speed * 0.0015,
		-deg_to_rad(22.0),
		deg_to_rad(22.0)
	)

	if not grounded:
		target_torso_angle += clampf(
			torso.linear_velocity.y * 0.0003,
			-deg_to_rad(7.0),
			deg_to_rad(7.0)
		)

	apply_angle_spring(
		torso,
		target_torso_angle,
		BODY_UPRIGHT_SPRING,
		BODY_UPRIGHT_DAMPING
	)
	# Keep the torso from tipping into a horizontal pile while still allowing
	# visible lean and impact motion.
	if absf(torso.global_rotation) > deg_to_rad(32.0):
		var correction := -signf(torso.global_rotation) * 80.0
		torso.apply_torque(correction)

	# --------------------------------------------------------------
	# Head: loose but follows the torso.
	# --------------------------------------------------------------
	var head_target := (torso.global_position + Vector2(0.0, HEAD_Y)).angle_to_point(
		head.global_position
	)
	var desired_head_angle := torso.global_rotation + clampf(
		-torso.linear_velocity.x * 0.0012,
		-deg_to_rad(12.0),
		deg_to_rad(12.0)
	)
	apply_angle_spring(
		head,
		desired_head_angle,
		HEAD_SPRING,
		HEAD_DAMPING
	)

	# --------------------------------------------------------------
	# Human walking targets.
	# The physical segments are steered toward these directions.
	# --------------------------------------------------------------
	var left_phase := fposmod(walk_phase, TAU)
	var right_phase := fposmod(walk_phase + PI, TAU)

	var left_leg_target := leg_target_angle(left_phase, -1.0, grounded)
	var right_leg_target := leg_target_angle(right_phase, 1.0, grounded)

	drive_leg(
		upper_leg_l,
		lower_leg_l,
		left_leg_target,
		-1.0,
		delta
	)
	drive_leg(
		upper_leg_r,
		lower_leg_r,
		right_leg_target,
		1.0,
		delta
	)

	# --------------------------------------------------------------
	# Arms hang naturally while walking. During an attack the active
	# arm gets a much stronger target, but remains physically jointed.
	# --------------------------------------------------------------
	var arm_swing := sin(walk_phase) * 0.42 * clampf(absf(speed) / MOVE_SPEED, 0.0, 1.0)

	var left_arm_angle := -0.48 - arm_swing * facing
	var right_arm_angle := 0.48 + arm_swing * facing

	if attack_timer > 0.0:
		var attack_progress := 1.0 - attack_timer / ATTACK_DURATION
		var punch_curve := sin(clampf(attack_progress, 0.0, 1.0) * PI)

		if facing > 0.0:
			right_arm_angle = lerpf(right_arm_angle, -0.12, punch_curve)
			left_arm_angle = lerpf(left_arm_angle, 0.85, punch_curve * 0.45)
		else:
			left_arm_angle = lerpf(left_arm_angle, 0.12, punch_curve)
			right_arm_angle = lerpf(right_arm_angle, -0.85, punch_curve * 0.45)

	drive_arm(
		upper_arm_l,
		lower_arm_l,
		left_arm_angle,
		-1.0,
		delta
	)
	drive_arm(
		upper_arm_r,
		lower_arm_r,
		right_arm_angle,
		1.0,
		delta
	)


func leg_target_angle(phase: float, side: float, grounded: bool) -> float:
	if not grounded:
		return deg_to_rad(8.0) * side + torso.rotation

	var stride := sin(phase) * 0.42
	var lift := maxf(0.0, sin(phase)) * 0.20

	# The leg moves forward during its swing and trails during support.
	return torso.rotation + stride * facing + lift * side * facing


func drive_leg(
	upper: RigidBody2D,
	lower: RigidBody2D,
	target_angle: float,
	side: float,
	delta: float
):
	apply_angle_spring(upper, target_angle, LEG_SPRING, LEG_DAMPING)

	var knee_angle := 0.12 + maxf(0.0, sin(walk_phase + (0.0 if side < 0.0 else PI))) * 0.38
	apply_angle_spring(
		lower,
		target_angle - knee_angle * facing * side,
		LEG_SPRING * 0.72,
		LEG_DAMPING
	)

	# A tiny alternating force helps the foot swing without directly
	# teleporting it.
	if is_grounded():
		var forward_force := sin(walk_phase + (PI if side > 0.0 else 0.0))
		lower.apply_central_force(Vector2(
			forward_force * WALK_FORCE * facing,
			0.0
		))


func drive_arm(
	upper: RigidBody2D,
	lower: RigidBody2D,
	target_angle: float,
	side: float,
	delta: float
):
	apply_angle_spring(upper, target_angle, ARM_SPRING, ARM_DAMPING)

	var elbow_target := target_angle + side * 0.30
	if attack_timer <= 0.0:
		elbow_target = target_angle + side * 0.18

	apply_angle_spring(
		lower,
		elbow_target,
		ARM_SPRING * 0.82,
		ARM_DAMPING
	)


func apply_angle_spring(
	body: RigidBody2D,
	target_angle: float,
	stiffness: float,
	damping: float
):
	var error := wrapf(target_angle - body.global_rotation, -PI, PI)
	var torque := error * stiffness - body.angular_velocity * damping
	body.apply_torque(torque)


func start_attack():
	attack_timer = ATTACK_DURATION
	attack_cooldown = ATTACK_COOLDOWN

	var punch_direction := Vector2(facing, 0.0)

	# The punch starts with a small whole-body counter-motion.
	torso.apply_central_impulse(-punch_direction * 12.0)
	torso.apply_torque(-facing * ATTACK_BODY_TORQUE)


func update_attack(_delta: float):
	if attack_timer <= 0.0:
		return

	var progress := 1.0 - attack_timer / ATTACK_DURATION
	var punch_curve := sin(clampf(progress, 0.0, 1.0) * PI)

	# Apply force to the striking forearm instead of setting its position.
	var striking_arm := lower_arm_r if facing > 0.0 else lower_arm_l
	var force := Vector2(facing, 0.0) * ATTACK_FORCE * punch_curve

	striking_arm.apply_central_force(force)

	# The hit check is intentionally small and only active near the
	# middle of the punch.
	if progress > 0.32 and progress < 0.72:
		try_hit_near_hand()


func try_hit_near_hand():
	var hand := get_hand_position()
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ATTACK_HIT_RADIUS
	query.shape = shape
	query.transform = Transform2D(0.0, hand)
	query.collision_mask = 2
	query.collide_with_bodies = true

	# Never hit our own ragdoll segments.
	query.exclude = ragdoll_parts.map(func(part): return part.get_rid())

	var space := get_world_2d().direct_space_state
	var results := space.intersect_shape(query, 8)

	for result in results:
		var body = result.get("collider")
		if body == null:
			continue

		if body.has_method("receive_hit"):
			body.receive_hit(
				Vector2(facing, -0.12).normalized(),
				ATTACK_FORCE * 0.65
			)
		elif body is RigidBody2D:
			body.apply_central_impulse(
				Vector2(facing, -0.12).normalized() * ATTACK_FORCE * 0.65
			)


func receive_hit(direction: Vector2, strength: float):
	# Public API for another fighter's hitbox.
	# The response is a physical impulse, so the result depends on the
	# current pose rather than being a fixed animation.
	var impulse := direction.normalized() * strength

	torso.apply_central_impulse(impulse * 0.75)
	head.apply_central_impulse(impulse * 0.10)
	upper_arm_l.apply_central_impulse(impulse * 0.06)
	upper_arm_r.apply_central_impulse(impulse * 0.06)
	upper_leg_l.apply_central_impulse(impulse * 0.08)
	upper_leg_r.apply_central_impulse(impulse * 0.08)

	torso.apply_torque(-direction.x * strength * 0.045)


func get_hand_position() -> Vector2:
	var arm := lower_arm_r if facing > 0.0 else lower_arm_l
	var offset := Vector2(ARM_LENGTH * 0.30 * facing, 0.0)
	return arm.global_position + offset.rotated(arm.global_rotation)


func _draw():
	# Draw a tiny motion indicator under the physical body. The actual
	# fighter is rendered by its RigidBody2D visual children.
	if not initialized:
		return

	var speed := absf(torso.linear_velocity.x)
	if speed > 60.0:
		var alpha := clampf(speed / MOVE_SPEED, 0.0, 1.0) * 0.18
		draw_line(
			Vector2(-14.0 * facing, 20.0),
			Vector2(-30.0 * facing, 20.0),
			Color(MINT_GREEN, alpha),
			2.0
		)


class SegmentVisual extends Node2D:
	var segment_length := 20.0
	var radius := 3.0
	var color := Color.WHITE

	func setup(length: float, segment_radius: float, segment_color: Color):
		segment_length = maxf(length, 2.0)
		radius = segment_radius
		color = segment_color
		queue_redraw()

	func _draw():
		draw_line(
			Vector2(0.0, -segment_length * 0.5),
			Vector2(0.0, segment_length * 0.5),
			color,
			radius * 2.0,
			true
		)
		draw_circle(Vector2(0.0, -segment_length * 0.5), radius, color)
		draw_circle(Vector2(0.0, segment_length * 0.5), radius, color)


class CircleVisual extends Node2D:
	var radius := 10.0
	var color := Color.WHITE

	func setup(circle_radius: float, circle_color: Color):
		radius = circle_radius
		color = circle_color
		queue_redraw()

	func _draw():
		draw_circle(Vector2.ZERO, radius, color)
