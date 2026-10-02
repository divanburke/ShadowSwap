extends CharacterBody2D

const LimbScript = preload("res://scripts/limb.gd")

# ------------------------------------------------------------------
# SHADOWSWAP FIGHTER
# ------------------------------------------------------------------
# One stable CharacterBody2D controls the complete fighter.
# The body is intentionally simple and reliable:
#   - capsule collision = the fighter's solid physical body
#   - direct velocity control = responsive movement
#   - gravity + acceleration = physical-feeling momentum
#   - procedural limbs = clean Stick Fight-style silhouette
#   - detached pieces = separate rigid bodies after a part is lost
# ------------------------------------------------------------------

const BODY_RADIUS = 14.0
const BODY_HEIGHT = 70.0

const RUN_SPEED = 315.0
const RUN_ACCELERATION = 2100.0
const RUN_DECELERATION = 2500.0
const AIR_ACCELERATION = 900.0
const AIR_DECELERATION = 350.0

const GRAVITY = 1650.0
const MAX_FALL_SPEED = 950.0
const JUMP_SPEED = 570.0
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

const PUNCH_REACH = 68.0
const KICK_REACH = 78.0
const PUNCH_TIME = 0.18
const KICK_TIME = 0.24
const PUNCH_COOLDOWN = 0.28
const KICK_COOLDOWN = 0.40

const HIT_STAGGER = 0.16
const HIT_SPEED_TRANSFER = 0.32

const SHADOW_TIME = 4.0
const SHADOW_COOLDOWN = 11.0

var owner_game
var is_player = false
var fighter_name = "PLAYER"

# Both players are rendered as a single solid color.
var base_color = Color("#f4f7ff")

var defeated = false
var facing = 1.0

var health = {
	"head": 2.0,
	"torso": 5.0,
	"left_arm": 2.0,
	"right_arm": 2.0,
	"left_leg": 2.0,
	"right_leg": 2.0
}

var detached = {
	"head": false,
	"torso": false,
	"left_arm": false,
	"right_arm": false,
	"left_leg": false,
	"right_leg": false
}

var attack_kind = ""
var attack_timer = 0.0
var attack_cooldown = 0.0
var stagger_timer = 0.0

var coyote_timer = 0.0
var jump_buffer_timer = 0.0

var shadow_mode_time = 0.0
var shadow_mode_cooldown = 0.0

var jump_was_down = false
var punch_was_down = false
var kick_was_down = false
var shadow_was_down = false

var ai_rng = RandomNumberGenerator.new()
var ai_timer = 0.0
var ai_jump_timer = 0.0
var ai_move_direction = 0.0

var walk_phase = 0.0
var was_on_floor = false


func setup(game, display_name, player_control, start_position, p_color, p_accent):
	owner_game = game
	fighter_name = display_name
	is_player = player_control

	# Ignore the old accent parameter on purpose. The character is one solid color.
	base_color = p_color

	ai_rng.randomize()

	global_position = start_position

	# Layer 2 = fighters. Layer 1 = arena.
	collision_layer = 2
	collision_mask = 3

	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_stop_on_slope = true
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.08

	build_body_collision()
	queue_redraw()


func build_body_collision():
	var collision = CollisionShape2D.new()
	collision.name = "FighterCollision"

	var capsule = CapsuleShape2D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT

	collision.shape = capsule
	collision.position = Vector2(0.0, 2.0)

	add_child(collision)


func _physics_process(delta):
	if defeated:
		return

	update_timers(delta)

	if is_player:
		read_player_input()
	else:
		update_ai(delta)

	update_fighter_movement(delta)
	update_animation(delta)

	queue_redraw()


func update_timers(delta):
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	stagger_timer = maxf(stagger_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	shadow_mode_cooldown = maxf(shadow_mode_cooldown - delta, 0.0)

	if attack_timer > 0.0:
		attack_timer -= delta

		if attack_timer <= 0.0:
			attack_timer = 0.0
			attack_kind = ""

	if shadow_mode_time > 0.0:
		shadow_mode_time -= delta

		if shadow_mode_time <= 0.0:
			shadow_mode_time = 0.0
			queue_redraw()


func read_player_input():
	var move = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move += 1.0

	if move != 0.0:
		facing = move
		ai_move_direction = move
	else:
		ai_move_direction = 0.0

	var jump = Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var punch = Input.is_key_pressed(KEY_J)
	var kick = Input.is_key_pressed(KEY_K)
	var shadow = Input.is_key_pressed(KEY_E)

	if jump and not jump_was_down:
		jump_buffer_timer = JUMP_BUFFER_TIME

	if punch and not punch_was_down:
		try_attack("punch")

	if kick and not kick_was_down:
		try_attack("kick")

	if shadow and not shadow_was_down:
		try_shadow_mode()

	# Short press = lower jump, held press = full jump.
	if not jump and jump_was_down and velocity.y < -180.0:
		velocity.y *= 0.50

	jump_was_down = jump
	punch_was_down = punch
	kick_was_down = kick
	shadow_was_down = shadow


func update_ai(delta):
	var opponent = owner_game.call("get_opponent", self)

	if opponent == null or opponent.defeated:
		ai_move_direction = 0.0
		return

	var dx = opponent.global_position.x - global_position.x
	var distance = absf(dx)

	if absf(dx) > 6.0:
		facing = sign(dx)

	ai_timer -= delta
	ai_jump_timer -= delta

	if ai_timer > 0.0:
		return

	ai_timer = ai_rng.randf_range(0.08, 0.16)

	var desired = sign(dx)

	if opponent.shadow_mode_time > 0.0 and distance < 190.0:
		desired = -desired
	elif distance < 105.0 and ai_rng.randf() < 0.17:
		desired = -desired

	ai_move_direction = desired

	if attack_cooldown <= 0.0 and distance < KICK_REACH + 18.0:
		if ai_rng.randf() < 0.55:
			try_attack("punch")
		else:
			try_attack("kick")

	if shadow_mode_cooldown <= 0.0 and shadow_mode_time <= 0.0:
		if distance < 200.0 and ai_rng.randf() < 0.12:
			try_shadow_mode()

	if ai_jump_timer <= 0.0 and ai_rng.randf() < 0.20:
		ai_jump_timer = ai_rng.randf_range(0.7, 1.5)

		if distance > 115.0 or opponent.is_attack_active():
			try_jump()


func update_fighter_movement(delta):
	# Refresh grounded state after the previous physics step.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	elif was_on_floor and velocity.y >= 0.0:
		coyote_timer = COYOTE_TIME

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		do_jump()

	var move_direction = ai_move_direction

	if not is_player:
		move_direction = ai_move_direction

	var leg_factor = get_leg_factor()

	if stagger_timer > 0.0:
		move_direction *= 0.25

	var target_speed = move_direction * RUN_SPEED * leg_factor

	var acceleration = RUN_ACCELERATION
	var deceleration = RUN_DECELERATION

	if not is_on_floor():
		acceleration = AIR_ACCELERATION
		deceleration = AIR_DECELERATION

	if move_direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			target_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	# With both legs gone the fighter can slide along the floor but cannot jump.
	move_and_slide()

	was_on_floor = is_on_floor()

	if is_on_floor() and absf(velocity.x) < 2.0:
		velocity.x = 0.0


func do_jump():
	if get_jump_factor() <= 0.0:
		return

	jump_buffer_timer = 0.0
	coyote_timer = 0.0

	velocity.y = -JUMP_SPEED * get_jump_factor()


func try_jump():
	if defeated:
		return

	jump_buffer_timer = JUMP_BUFFER_TIME

	if coyote_timer > 0.0:
		do_jump()


func get_jump_factor():
	if detached["left_leg"] and detached["right_leg"]:
		return 0.0

	if detached["left_leg"] or detached["right_leg"]:
		return 0.78

	return 1.0


func update_animation(delta):
	if is_on_floor() and absf(velocity.x) > 18.0:
		walk_phase += absf(velocity.x) * delta * 0.035
	else:
		walk_phase = move_toward(
			walk_phase,
			0.0,
			delta * 3.0
		)


func get_part_position(part_name):
	var walk = 0.0
	var jump = 0.0

	if is_on_floor() and absf(velocity.x) > 18.0:
		walk = sin(walk_phase) * 5.0
	else:
		walk = sin(walk_phase) * 1.5

	if not is_on_floor():
		jump = clampf(-velocity.y / JUMP_SPEED, -0.35, 0.55)

	var punch_progress = 0.0

	if attack_kind != "":
		var duration = PUNCH_TIME if attack_kind == "punch" else KICK_TIME
		punch_progress = 1.0 - attack_timer / duration
		punch_progress = clampf(punch_progress, 0.0, 1.0)

	match part_name:
		"head":
			return global_position + Vector2(0.0, -47.0 - jump * 2.0)

		"torso":
			return global_position

		"left_arm":
			if attack_kind == "punch" and facing < 0.0:
				return global_position + Vector2(
					-17.0 - 25.0 * punch_progress,
					-5.0
				)

			return global_position + Vector2(
				-18.0,
				7.0 + walk * 0.35
			)

		"right_arm":
			if attack_kind == "punch" and facing > 0.0:
				return global_position + Vector2(
					17.0 + 25.0 * punch_progress,
					-5.0
				)

			return global_position + Vector2(
				18.0,
				7.0 - walk * 0.35
			)

		"left_leg":
			return global_position + Vector2(
				-10.0 - walk * 0.75,
				42.0
			)

		"right_leg":
			return global_position + Vector2(
				10.0 + walk * 0.75,
				42.0
			)

	return global_position


func get_attack_origin(kind):
	var position = global_position

	if kind == "kick":
		position += Vector2(facing * 26.0, 31.0)
	elif facing > 0.0:
		position = get_part_position("right_arm")
	else:
		position = get_part_position("left_arm")

	return position


func try_attack(kind):
	if defeated or attack_cooldown > 0.0:
		return

	if kind == "punch":
		if detached["left_arm"] and detached["right_arm"]:
			return

		attack_kind = "punch"
		attack_timer = PUNCH_TIME
		attack_cooldown = PUNCH_COOLDOWN
	else:
		if detached["left_leg"] and detached["right_leg"]:
			return

		attack_kind = "kick"
		attack_timer = KICK_TIME
		attack_cooldown = KICK_COOLDOWN

	var opponent = owner_game.call("get_opponent", self)

	if opponent == null or opponent.defeated:
		return

	var origin = get_attack_origin(kind)
	var reach = PUNCH_REACH if kind == "punch" else KICK_REACH
	var target_name = opponent.find_attack_target(origin, reach, facing)

	if target_name == "":
		return

	var target_position = opponent.get_part_position(target_name)
	var direction = sign(target_position.x - origin.x)

	if direction == 0.0:
		direction = facing

	var force = 430.0 if kind == "punch" else 600.0
	var vertical = -0.10 if kind == "punch" else -0.26
	var damage = 1.0

	if shadow_mode_time > 0.0:
		force *= 1.45
		damage = 1.35

	opponent.receive_hit(
		target_name,
		damage,
		Vector2(
			direction * force,
			force * vertical
		),
		kind
	)

	velocity.x -= facing * 20.0


func find_attack_target(origin, reach, direction):
	var best = ""
	var best_distance = reach

	for part_name in detached.keys():
		if detached[part_name]:
			continue

		var target = get_part_position(part_name)
		var offset = target - origin
		var distance = offset.length()

		if distance > reach:
			continue

		# Only hit targets in front of the attacker.
		if offset.x * direction < -10.0:
			continue

		if distance < best_distance:
			best_distance = distance
			best = part_name

	return best


func is_attack_active():
	return attack_kind != "" and attack_timer > 0.0


func receive_hit(part_name, damage, impulse, attack_kind_name):
	if defeated or shadow_mode_time > 0.0:
		return

	if not health.has(part_name):
		return

	health[part_name] -= damage

	velocity += impulse * HIT_SPEED_TRANSFER * 0.08
	stagger_timer = HIT_STAGGER

	if attack_kind_name != "":
		owner_game.call(
			"report_hit",
			fighter_name,
			part_name,
			attack_kind_name
		)

	if health[part_name] <= 0.0:
		detach_part(part_name)

	queue_redraw()


func detach_part(part_name):
	if detached.get(part_name, false):
		return

	detached[part_name] = true

	var body = LimbScript.new()
	body.name = fighter_name + "_Detached_" + part_name
	owner_game.arena_root.add_child(body)
	body.global_position = get_part_position(part_name)

	var size = Vector2(8.0, 38.0)
	var kind = "pill"

	match part_name:
		"head":
			size = Vector2(14.0, 14.0)
			kind = "circle"

		"torso":
			size = Vector2(12.0, 44.0)
			kind = "pill"

		"left_arm", "right_arm":
			size = Vector2(8.0, 38.0)
			kind = "pill"

		"left_leg", "right_leg":
			size = Vector2(9.0, 42.0)
			kind = "pill"

	body.setup(
		part_name,
		size,
		base_color,
		base_color,
		kind
	)

	body.collision_layer = 4
	body.collision_mask = 3
	body.linear_velocity = velocity
	body.angular_velocity = facing * 2.5

	body.apply_central_impulse(
		Vector2(
			facing * 90.0,
			-110.0
		)
	)

	owner_game.call(
		"part_lost",
		self,
		part_name
	)

	if part_name == "head" or part_name == "torso":
		defeated = true
	elif get_detached_count() >= 4:
		defeated = true

	if defeated:
		velocity = Vector2.ZERO
		owner_game.call_deferred(
			"fighter_defeated",
			self
		)


func get_detached_count():
	var count = 0

	for part_name in detached.keys():
		if detached[part_name]:
			count += 1

	return count


func get_leg_factor():
	if detached["left_leg"] and detached["right_leg"]:
		return 0.35

	if detached["left_leg"] or detached["right_leg"]:
		return 0.70

	return 1.0


func can_shadow_mode():
	return (
		not defeated
		and shadow_mode_time <= 0.0
		and shadow_mode_cooldown <= 0.0
	)


func try_shadow_mode():
	if not can_shadow_mode():
		return

	shadow_mode_time = SHADOW_TIME
	shadow_mode_cooldown = SHADOW_COOLDOWN

	owner_game.call(
		"shadow_mode_started",
		self
	)

	queue_redraw()


func set_shadow_visual(_value):
	queue_redraw()


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


# ------------------------------------------------------------------
# VISUALS
# ------------------------------------------------------------------

func _draw():
	var color = base_color

	# Shadow Mode remains a single solid fill.
	if shadow_mode_time > 0.0:
		color = Color("#d8c9ff")

	if stagger_timer > 0.0:
		color = Color("#ffffff")

	# HEAD
	if not detached["head"]:
		draw_circle(
			Vector2(0.0, -47.0),
			14.0,
			color
		)

	# TORSO: thick pill-like central body.
	if not detached["torso"]:
		draw_pill(
			Vector2(0.0, -29.0),
			Vector2(0.0, 17.0),
			9.0,
			color
		)

	# ARMS
	if not detached["left_arm"]:
		var left_hand = get_part_position("left_arm") - global_position
		draw_pill(
			Vector2(-8.0, -20.0),
			left_hand,
			7.0,
			color
		)

	if not detached["right_arm"]:
		var right_hand = get_part_position("right_arm") - global_position
		draw_pill(
			Vector2(8.0, -20.0),
			right_hand,
			7.0,
			color
		)

	# LEGS
	if not detached["left_leg"]:
		var left_knee = Vector2(-6.0, 17.0)
		var left_foot = get_part_position("left_leg") - global_position
		left_foot += Vector2(-2.0, 12.0)

		draw_pill(
			left_knee,
			left_foot,
			8.0,
			color
		)

	if not detached["right_leg"]:
		var right_knee = Vector2(6.0, 17.0)
		var right_foot = get_part_position("right_leg") - global_position
		right_foot += Vector2(2.0, 12.0)

		draw_pill(
			right_knee,
			right_foot,
			8.0,
			color
		)


func draw_pill(start_point, end_point, width, color):
	var radius = width * 0.5

	draw_line(
		start_point,
		end_point,
		color,
		width,
		true
	)

	draw_circle(
		start_point,
		radius,
		color
	)

	draw_circle(
		end_point,
		radius,
		color
	)
