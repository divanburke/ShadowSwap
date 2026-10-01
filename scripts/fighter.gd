extends Node2D

const LimbScript = preload("res://scripts/limb.gd")

const BODY_SIZE = Vector2(30, 58)
const HEAD_RADIUS = 18.0
const ARM_SIZE = Vector2(12, 42)
const LEG_SIZE = Vector2(14, 48)

const NORMAL_SPEED = 820.0
const JUMP_IMPULSE = 410.0
const PUNCH_REACH = 64.0
const KICK_REACH = 76.0

var owner_game
var is_player = false
var fighter_name = "PLAYER"
var base_color = Color("#f4f7ff")
var accent_color = Color("#55d6ff")

var parts = {}
var joints = {}

var health = {
	"head": 2,
	"torso": 5,
	"left_arm": 2,
	"right_arm": 2,
	"left_leg": 2,
	"right_leg": 2
}

var detached = {
	"head": false,
	"torso": false,
	"left_arm": false,
	"right_arm": false,
	"left_leg": false,
	"right_leg": false
}

var defeated = false
var facing = 1.0

var attack_cooldown = 0.0
var jump_cooldown = 0.0
var shadow_mode_cooldown = 0.0
var shadow_mode_time = 0.0

var punch_was_down = false
var kick_was_down = false
var jump_was_down = false
var shadow_was_down = false

var ai_think_timer = 0.0
var ai_jump_timer = 0.0
var ai_rng = RandomNumberGenerator.new()

var torso_ray


func setup(game, display_name, player_control, start_position, p_color, p_accent):
	owner_game = game
	fighter_name = display_name
	is_player = player_control
	base_color = p_color
	accent_color = p_accent

	position = Vector2.ZERO
	ai_rng.randomize()

	spawn_body(start_position)


func spawn_body(start_position):
	var torso_position = start_position
	var head_position = start_position + Vector2(0, -48)
	var left_arm_position = start_position + Vector2(-29, -3)
	var right_arm_position = start_position + Vector2(29, -3)
	var left_leg_position = start_position + Vector2(-11, 52)
	var right_leg_position = start_position + Vector2(11, 52)

	parts["torso"] = create_part("torso", torso_position, BODY_SIZE, "rect")
	parts["head"] = create_part("head", head_position, Vector2(HEAD_RADIUS, HEAD_RADIUS), "circle")
	parts["left_arm"] = create_part("left_arm", left_arm_position, ARM_SIZE, "rect")
	parts["right_arm"] = create_part("right_arm", right_arm_position, ARM_SIZE, "rect")
	parts["left_leg"] = create_part("left_leg", left_leg_position, LEG_SIZE, "rect")
	parts["right_leg"] = create_part("right_leg", right_leg_position, LEG_SIZE, "rect")

	joints["head"] = make_joint(parts["torso"], parts["head"], torso_position + Vector2(0, -28))
	joints["left_arm"] = make_joint(parts["torso"], parts["left_arm"], torso_position + Vector2(-16, -15))
	joints["right_arm"] = make_joint(parts["torso"], parts["right_arm"], torso_position + Vector2(16, -15))
	joints["left_leg"] = make_joint(parts["torso"], parts["left_leg"], torso_position + Vector2(-10, 28))
	joints["right_leg"] = make_joint(parts["torso"], parts["right_leg"], torso_position + Vector2(10, 28))

	torso_ray = RayCast2D.new()
	torso_ray.target_position = Vector2(0, 43)
	torso_ray.collision_mask = 1
	torso_ray.enabled = true
	parts["torso"].add_child(torso_ray)


func create_part(part_name, world_position, size_value, shape_kind):
	var limb = LimbScript.new()
	limb.name = fighter_name + "_" + part_name
	limb.position = world_position
	add_child(limb)
	limb.setup(part_name, size_value, base_color, accent_color, shape_kind)
	return limb


func make_joint(body_a, body_b, anchor_position):
	var joint = PinJoint2D.new()
	joint.name = body_a.name + "_TO_" + body_b.name
	joint.position = anchor_position
	joint.disable_collision = true
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	add_child(joint)
	return joint


func _physics_process(delta):
	if defeated:
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	jump_cooldown = maxf(jump_cooldown - delta, 0.0)
	shadow_mode_cooldown = maxf(shadow_mode_cooldown - delta, 0.0)

	if shadow_mode_time > 0.0:
		shadow_mode_time = maxf(shadow_mode_time - delta, 0.0)
		if shadow_mode_time <= 0.0:
			set_shadow_visual(false)

	if is_player:
		handle_player_input()
	else:
		handle_ai(delta)

	apply_stability()


func apply_stability():
	var torso = parts.get("torso")
	if torso == null or detached["torso"]:
		return

	var leg_factor = get_leg_factor()
	var move_force = NORMAL_SPEED * leg_factor

	var horizontal = 0.0

	if is_player:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			horizontal -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			horizontal += 1.0

	if horizontal != 0.0:
		torso.apply_central_force(Vector2(horizontal * move_force, 0))

		var velocity_limit = 260.0 * maxf(leg_factor, 0.35)
		if absf(torso.linear_velocity.x) > velocity_limit:
			torso.linear_velocity.x = move_toward(
				torso.linear_velocity.x,
				sign(torso.linear_velocity.x) * velocity_limit,
				18.0
			)


func handle_player_input():
	var torso = parts.get("torso")
	if torso == null:
		return

	var move_direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_direction -= 1.0
		facing = -1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_direction += 1.0
		facing = 1.0

	var jump_down = Input.is_key_pressed(KEY_UP)
	var punch_down = Input.is_key_pressed(KEY_J)
	var kick_down = Input.is_key_pressed(KEY_K)
	var shadow_down = Input.is_key_pressed(KEY_E)

	if jump_down and not jump_was_down:
		try_jump()

	if punch_down and not punch_was_down:
		try_attack("punch")

	if kick_down and not kick_was_down:
		try_attack("kick")

	if shadow_down and not shadow_was_down:
		try_shadow_mode()

	jump_was_down = jump_down
	punch_was_down = punch_down
	kick_was_down = kick_down
	shadow_was_down = shadow_down


func handle_ai(delta):
	var opponent = owner_game.call("get_opponent", self)
	if opponent == null or opponent.defeated:
		return

	var torso = parts.get("torso")
	var opponent_torso = opponent.parts.get("torso")

	if torso == null or opponent_torso == null:
		return

	var dx = opponent_torso.global_position.x - torso.global_position.x
	var distance = absf(dx)

	if dx < -8.0:
		facing = -1.0
	elif dx > 8.0:
		facing = 1.0

	ai_think_timer -= delta
	ai_jump_timer -= delta

	if ai_think_timer <= 0.0:
		ai_think_timer = ai_rng.randf_range(0.12, 0.28)

		var desired = sign(dx)

		if distance < 170.0:
			if opponent.shadow_mode_time > 0.0 and shadow_mode_time <= 0.0:
				desired = -sign(dx)
			elif ai_rng.randf() < 0.28:
				desired = -desired

			if attack_cooldown <= 0.0 and distance < KICK_REACH + 8.0:
				if ai_rng.randf() < 0.52:
					try_attack("punch")
				else:
					try_attack("kick")

		if shadow_mode_cooldown <= 0.0 and shadow_mode_time <= 0.0:
			if distance < 150.0 and ai_rng.randf() < 0.16:
				try_shadow_mode()

		if ai_jump_timer <= 0.0 and ai_rng.randf() < 0.22:
			ai_jump_timer = ai_rng.randf_range(0.8, 1.8)
			if distance > 90.0 or opponent.is_attack_active():
				try_jump()

		if desired != 0.0:
			torso.apply_central_force(Vector2(desired * NORMAL_SPEED * get_leg_factor() * 0.85, 0))


func is_attack_active():
	return attack_cooldown > 0.30


func try_jump():
	if jump_cooldown > 0.0:
		return

	if detached["torso"]:
		return

	if torso_ray != null and not torso_ray.is_colliding():
		return

	var leg_factor = get_leg_factor()
	if leg_factor <= 0.35:
		return

	var torso = parts.get("torso")
	if torso == null:
		return

	torso.apply_central_impulse(Vector2(0, -JUMP_IMPULSE * (0.70 + leg_factor * 0.35)))
	jump_cooldown = 0.55


func try_attack(kind):
	if attack_cooldown > 0.0 or defeated:
		return

	var has_arms = not detached["left_arm"] or not detached["right_arm"]
	var has_legs = not detached["left_leg"] or not detached["right_leg"]

	if kind == "punch" and not has_arms:
		return

	if kind == "kick" and not has_legs:
		return

	var opponent = owner_game.call("get_opponent", self)
	if opponent == null or opponent.defeated:
		return

	var torso = parts.get("torso")
	if torso == null:
		return

	var reach = PUNCH_REACH
	var damage = 1.0
	var knockback = 520.0
	var origin = torso.global_position + Vector2(facing * 27.0, 0)

	if kind == "kick":
		reach = KICK_REACH
		origin += Vector2(0, 24)
		damage = 1.0
		knockback = 670.0

	var target_name = find_target(opponent, origin, reach)

	if target_name != "":
		var target = opponent.parts.get(target_name)
		if target != null and not opponent.detached[target_name]:
			var direction = sign(target.global_position.x - origin.x)
			if direction == 0.0:
				direction = facing

			var vertical = -0.20
			if kind == "kick":
				vertical = -0.36

			var boost = 1.0
			if shadow_mode_time > 0.0:
				boost = 1.45

			var impulse = Vector2(
				direction * knockback * boost,
				knockback * vertical * boost
			)

			opponent.receive_hit(target_name, damage * boost, impulse, kind)

		# The attacking body also gets a small reaction force.
		torso.apply_central_impulse(Vector2(-facing * 35.0, -20.0))

	attack_cooldown = 0.52 if kind == "punch" else 0.68


func find_target(opponent, origin, reach):
	var best = ""
	var best_distance = reach

	for part_name in opponent.parts.keys():
		if opponent.detached.get(part_name, false):
			continue

		var part = opponent.parts.get(part_name)
		if part == null:
			continue

		var distance = origin.distance_to(part.global_position)

		if distance < best_distance:
			best_distance = distance
			best = part_name

	return best


func receive_hit(part_name, damage, impulse, attack_kind):
	if defeated:
		return

	if shadow_mode_time > 0.0:
		return

	if not health.has(part_name):
		return

	health[part_name] -= damage

	var target = parts.get(part_name)
	if target != null:
		target.flash_hit()
		target.apply_central_impulse(impulse)

	var torso = parts.get("torso")
	if torso != null and not detached["torso"]:
		torso.apply_central_impulse(impulse * 0.30)

	if health[part_name] <= 0.0:
		detach_part(part_name)

	if attack_kind != "":
		owner_game.call("report_hit", fighter_name, part_name, attack_kind)


func detach_part(part_name):
	if detached.get(part_name, false):
		return

	detached[part_name] = true

	var joint = joints.get(part_name)
	if joint != null:
		joint.queue_free()
		joints[part_name] = null

	var limb = parts.get(part_name)
	if limb != null:
		limb.collision_mask = 1
		limb.collision_layer = 2

		var burst = Vector2(
			facing * 65.0,
			-100.0
		)
		limb.apply_central_impulse(burst)

	owner_game.call("part_lost", self, part_name)

	if part_name == "head" or part_name == "torso":
		defeated = true
	elif get_detached_count() >= 4:
		defeated = true

	if defeated:
		owner_game.call_deferred("fighter_defeated", self)


func get_detached_count():
	var count = 0

	for part_name in detached.keys():
		if detached[part_name]:
			count += 1

	return count


func get_leg_factor():
	var left_lost = detached["left_leg"]
	var right_lost = detached["right_leg"]

	if left_lost and right_lost:
		return 0.35
	if left_lost or right_lost:
		return 0.65

	return 1.0


func can_shadow_mode():
	return shadow_mode_cooldown <= 0.0 and shadow_mode_time <= 0.0 and not defeated


func try_shadow_mode():
	if not can_shadow_mode():
		return

	shadow_mode_time = 4.0
	shadow_mode_cooldown = 11.0
	set_shadow_visual(true)
	owner_game.call("shadow_mode_started", self)


func set_shadow_visual(value):
	for part_name in parts.keys():
		var limb = parts[part_name]
		if limb != null:
			limb.set_shadowed(value)


func get_status_text():
	var text = ""

	if detached["head"]:
		text += "HEAD— "
	else:
		text += "HEAD OK  "

	if detached["left_arm"] and detached["right_arm"]:
		text += "ARMS—  "
	elif detached["left_arm"] or detached["right_arm"]:
		text += "ARM−1  "
	else:
		text += "ARMS OK  "

	if detached["left_leg"] and detached["right_leg"]:
		text += "LEGS—"
	elif detached["left_leg"] or detached["right_leg"]:
		text += "LEG−1"
	else:
		text += "LEGS OK"

	return text


func get_shadow_status():
	if shadow_mode_time > 0.0:
		return "SHADOW %.1f" % shadow_mode_time

	if shadow_mode_cooldown <= 0.0:
		return "READY"

	return "%.1f" % shadow_mode_cooldown
