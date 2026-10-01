extends Node2D

const LimbScript = preload("res://scripts/limb.gd")

# Compact stick-fighter proportions.
const BODY_SIZE = Vector2(14, 48)
const HEAD_RADIUS = 14.0
const ARM_SIZE = Vector2(8, 42)
const LEG_SIZE = Vector2(9, 46)

# Movement is intentionally direct and responsive, closer to an arcade fighter.
const MOVE_SPEED = 285.0
const ACCELERATION = 1900.0
const AIR_ACCELERATION = 1150.0
const GROUND_FRICTION = 2200.0
const AIR_FRICTION = 350.0
const JUMP_SPEED = 520.0
const MAX_FALL_SPEED = 760.0

const PUNCH_REACH = 62.0
const KICK_REACH = 74.0

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
	var head_position = start_position + Vector2(0, -42)
	var left_arm_position = start_position + Vector2(-18, -4)
	var right_arm_position = start_position + Vector2(18, -4)
	var left_leg_position = start_position + Vector2(-7, 45)
	var right_leg_position = start_position + Vector2(7, 45)

	parts["torso"] = create_part("torso", torso_position, BODY_SIZE, "rect")
	parts["head"] = create_part("head", head_position, Vector2(HEAD_RADIUS, HEAD_RADIUS), "circle")
	parts["left_arm"] = create_part("left_arm", left_arm_position, ARM_SIZE, "rect")
	parts["right_arm"] = create_part("right_arm", right_arm_position, ARM_SIZE, "rect")
	parts["left_leg"] = create_part("left_leg", left_leg_position, LEG_SIZE, "rect")
	parts["right_leg"] = create_part("right_leg", right_leg_position, LEG_SIZE, "rect")

	joints["head"] = make_joint(parts["torso"], parts["head"], torso_position + Vector2(0, -25))
	joints["left_arm"] = make_joint(parts["torso"], parts["left_arm"], torso_position + Vector2(-9, -17))
	joints["right_arm"] = make_joint(parts["torso"], parts["right_arm"], torso_position + Vector2(9, -17))
	joints["left_leg"] = make_joint(parts["torso"], parts["left_leg"], torso_position + Vector2(-6, 25))
	joints["right_leg"] = make_joint(parts["torso"], parts["right_leg"], torso_position + Vector2(6, 25))

	var torso = parts["torso"]
	torso.linear_damp = 6.0
	torso.angular_damp = 8.0


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
	add_child(joint)
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
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

	update_movement(delta)
	keep_torso_upright()


func keep_torso_upright():
	var torso = parts.get("torso")
	if torso == null or detached["torso"]:
		return

	# Keep the core upright while the connected limbs still swing physically.
	torso.rotation = 0.0
	torso.angular_velocity = 0.0


func handle_player_input():
	var torso = parts.get("torso")
	if torso == null:
		return

	var move_direction = Input.get_axis("ui_left", "ui_right")

	# Also support A/D without requiring the user to configure Input Map actions.
	if Input.is_key_pressed(KEY_A):
		move_direction = -1.0
	elif Input.is_key_pressed(KEY_D):
		move_direction = 1.0

	if move_direction != 0.0:
		facing = move_direction

	var jump_down = Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
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

	if absf(dx) > 8.0:
		facing = sign(dx)

	ai_think_timer -= delta
	ai_jump_timer -= delta

	if ai_think_timer <= 0.0:
		ai_think_timer = ai_rng.randf_range(0.08, 0.18)

		var desired = sign(dx)

		# Give the AI room to react to an opponent in Shadow Mode.
		if opponent.shadow_mode_time > 0.0 and distance < 180.0:
			desired = -sign(dx)
		elif distance < 120.0 and ai_rng.randf() < 0.18:
			desired = -desired

		if attack_cooldown <= 0.0 and distance < KICK_REACH + 12.0:
			if ai_rng.randf() < 0.55:
				try_attack("punch")
			else:
				try_attack("kick")

		if shadow_mode_cooldown <= 0.0 and shadow_mode_time <= 0.0:
			if distance < 190.0 and ai_rng.randf() < 0.12:
				try_shadow_mode()

		if ai_jump_timer <= 0.0 and ai_rng.randf() < 0.18:
			ai_jump_timer = ai_rng.randf_range(0.7, 1.5)
			if distance > 100.0 or opponent.is_attack_active():
				try_jump()

		set_ai_move(desired)


func set_ai_move(direction):
	if direction == 0.0:
		return

	facing = direction


func update_movement(delta):
	var torso = parts.get("torso")
	if torso == null or detached["torso"]:
		return

	var move_direction = 0.0

	if is_player:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_direction += 1.0
	else:
		var opponent = owner_game.call("get_opponent", self)
		if opponent != null and not opponent.defeated:
			var opponent_torso = opponent.parts.get("torso")
			if opponent_torso != null:
				move_direction = sign(opponent_torso.global_position.x - torso.global_position.x)

				if opponent.shadow_mode_time > 0.0 and absf(opponent_torso.global_position.x - torso.global_position.x) < 180.0:
					move_direction *= -1.0

				if absf(opponent_torso.global_position.x - torso.global_position.x) < 82.0 and ai_rng.randf() < 0.12:
					move_direction *= -1.0

	var leg_factor = get_leg_factor()
	var target_speed = move_direction * MOVE_SPEED * leg_factor
	var accel = ACCELERATION

	if not is_grounded():
		accel = AIR_ACCELERATION

	if move_direction == 0.0:
		var friction = GROUND_FRICTION
		if not is_grounded():
			friction = AIR_FRICTION

		torso.linear_velocity.x = move_toward(
			torso.linear_velocity.x,
			0.0,
			friction * delta
		)
	else:
		torso.linear_velocity.x = move_toward(
			torso.linear_velocity.x,
			target_speed,
			accel * delta
		)

	torso.linear_velocity.y = minf(torso.linear_velocity.y, MAX_FALL_SPEED)


func is_grounded():
	var torso = parts.get("torso")
	if torso == null:
		return false

	var ray = torso.get_node_or_null("GroundRay") as RayCast2D
	if ray == null:
		ray = RayCast2D.new()
		ray.name = "GroundRay"
		ray.target_position = Vector2(0, 86)
		ray.collision_mask = 1
		ray.enabled = true
		ray.position = Vector2(0, -2)
		torso.add_child(ray)

	ray.force_raycast_update()

	return ray.is_colliding()


func try_jump():
	if jump_cooldown > 0.0:
		return

	if detached["torso"]:
		return

	if get_leg_factor() <= 0.35:
		return

	var torso = parts.get("torso")
	if torso == null or not is_grounded():
		return

	torso.linear_velocity.y = -JUMP_SPEED * (0.72 + get_leg_factor() * 0.28)
	jump_cooldown = 0.28


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
	var knockback = 470.0
	var origin = torso.global_position + Vector2(facing * 26.0, 0)

	if kind == "kick":
		reach = KICK_REACH
		origin += Vector2(0, 20)
		knockback = 600.0

	var target_name = find_target(opponent, origin, reach)

	if target_name != "":
		var target = opponent.parts.get(target_name)

		if target != null and not opponent.detached[target_name]:
			var direction = sign(target.global_position.x - origin.x)

			if direction == 0.0:
				direction = facing

			var vertical = -0.15
			if kind == "kick":
				vertical = -0.30

			var boost = 1.0
			if shadow_mode_time > 0.0:
				boost = 1.4
				damage = 1.35

			var impulse = Vector2(
				direction * knockback * boost,
				knockback * vertical * boost
			)

			opponent.receive_hit(target_name, damage, impulse, kind)

			# Small recoil makes attacks feel physical without destroying control.
			torso.linear_velocity.x -= facing * 38.0

	attack_cooldown = 0.34 if kind == "punch" else 0.48


func find_target(opponent, origin, reach):
	var best = ""
	var best_score = reach

	for part_name in opponent.parts.keys():
		if opponent.detached.get(part_name, false):
			continue

		var part = opponent.parts.get(part_name)
		if part == null:
			continue

		var offset = part.global_position - origin
		var distance = offset.length()

		if distance > reach:
			continue

		# Prefer targets in front of the attacker, like a simple fighting hitbox.
		var front_score = 0.0

		if offset.x * facing < -6.0:
			front_score = 22.0

		var score = distance + front_score

		if score < best_score:
			best_score = score
			best = part_name

	return best


func is_attack_active():
	return attack_cooldown > 0.20


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
		torso.apply_central_impulse(impulse * 0.18)

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
		limb.apply_central_impulse(Vector2(
			facing * 120.0,
			-140.0
		))

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
