extends CharacterBody2D

const LimbScript = preload("res://scripts/limb.gd")

# Stable character-controller core with an animated stick-man body.
# Connected body parts are represented by the pose; detached parts become
# independent rigid bodies. This keeps walking/jumping reliable while hits
# still have physical knockback.

const RUN_SPEED = 310.0
const RUN_ACCEL = 2200.0
const RUN_DECEL = 2500.0
const AIR_ACCEL = 1050.0
const AIR_DECEL = 480.0

const GRAVITY = 1550.0
const MAX_FALL_SPEED = 900.0
const JUMP_SPEED = 560.0
const COYOTE_TIME = 0.10
const JUMP_BUFFER_TIME = 0.10

const PUNCH_REACH = 64.0
const KICK_REACH = 78.0

const PUNCH_DURATION = 0.22
const KICK_DURATION = 0.28
const PUNCH_COOLDOWN = 0.30
const KICK_COOLDOWN = 0.40

const HIT_STAGGER_TIME = 0.16
const HIT_KNOCKBACK = 0.78

const SHADOW_DURATION = 4.0
const SHADOW_COOLDOWN = 11.0

var owner_game
var is_player = false
var fighter_name = "PLAYER"
var base_color = Color("#f4f7ff")
var accent_color = Color("#55d6ff")

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

var defeated = false
var facing = 1.0

var attack_kind = ""
var attack_time = 0.0
var attack_cooldown = 0.0
var stagger_time = 0.0

var coyote_timer = 0.0
var jump_buffer_timer = 0.0

var shadow_mode_cooldown = 0.0
var shadow_mode_time = 0.0

var punch_was_down = false
var kick_was_down = false
var jump_was_down = false
var shadow_was_down = false

var ai_think_timer = 0.0
var ai_jump_timer = 0.0
var ai_rng = RandomNumberGenerator.new()
var ai_move_direction = 0.0

var run_cycle = 0.0
var landed_bounce = 0.0


func setup(game, display_name, player_control, start_position, p_color, p_accent):
	owner_game = game
	fighter_name = display_name
	is_player = player_control
	base_color = p_color
	accent_color = p_accent

	ai_rng.randomize()

	global_position = start_position
	collision_layer = 2
	collision_mask = 3

	floor_stop_on_slope = true
	floor_snap_length = 7.0
	floor_max_angle = deg_to_rad(50.0)

	build_collision()
	queue_redraw()


func build_collision():
	var collision = CollisionShape2D.new()
	collision.name = "BodyCollision"

	var shape = CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 76.0

	collision.shape = shape
	collision.position = Vector2(0, 3)
	add_child(collision)


func _physics_process(delta):
	if defeated:
		return

	update_timers(delta)

	if is_player:
		handle_player_input()
	else:
		handle_ai(delta)

	apply_character_physics(delta)
	update_pose(delta)

	if Input.is_action_just_pressed("ui_accept"):
		try_jump()

	queue_redraw()


func update_timers(delta):
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	stagger_time = maxf(stagger_time - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	shadow_mode_cooldown = maxf(shadow_mode_cooldown - delta, 0.0)

	if attack_time > 0.0:
		attack_time -= delta

		if attack_time <= 0.0:
			attack_time = 0.0
			attack_kind = ""

	if shadow_mode_time > 0.0:
		shadow_mode_time = maxf(shadow_mode_time - delta, 0.0)

		if shadow_mode_time <= 0.0:
			set_shadow_visual(false)


func handle_player_input():
	var move_direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_direction -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_direction += 1.0

	if move_direction != 0.0:
		facing = move_direction

	if move_direction == 0.0:
		ai_move_direction = 0.0
	else:
		ai_move_direction = move_direction

	var jump_down = Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var punch_down = Input.is_key_pressed(KEY_J)
	var kick_down = Input.is_key_pressed(KEY_K)
	var shadow_down = Input.is_key_pressed(KEY_E)

	if jump_down and not jump_was_down:
		jump_buffer_timer = JUMP_BUFFER_TIME

	if punch_down and not punch_was_down:
		try_attack("punch")

	if kick_down and not kick_was_down:
		try_attack("kick")

	if shadow_down and not shadow_was_down:
		try_shadow_mode()

	# Variable jump height: releasing jump early cuts upward velocity.
	if not jump_down and jump_was_down and velocity.y < -190.0:
		velocity.y *= 0.48

	jump_was_down = jump_down
	punch_was_down = punch_down
	kick_was_down = kick_down
	shadow_was_down = shadow_down


func handle_ai(delta):
	var opponent = owner_game.call("get_opponent", self)

	if opponent == null or opponent.defeated:
		ai_move_direction = 0.0
		return

	var dx = opponent.global_position.x - global_position.x
	var distance = absf(dx)

	if absf(dx) > 5.0:
		facing = sign(dx)

	ai_think_timer -= delta
	ai_jump_timer -= delta

	if ai_think_timer > 0.0:
		return

	ai_think_timer = ai_rng.randf_range(0.08, 0.16)

	var desired = sign(dx)

	if opponent.shadow_mode_time > 0.0 and distance < 190.0:
		desired = -sign(dx)
	elif distance < 110.0 and ai_rng.randf() < 0.16:
		desired = -desired

	ai_move_direction = desired

	if attack_cooldown <= 0.0 and distance < KICK_REACH + 18.0:
		if ai_rng.randf() < 0.55:
			try_attack("punch")
		else:
			try_attack("kick")

	if shadow_mode_cooldown <= 0.0 and shadow_mode_time <= 0.0:
		if distance < 200.0 and ai_rng.randf() < 0.11:
			try_shadow_mode()

	if ai_jump_timer <= 0.0 and ai_rng.randf() < 0.17:
		ai_jump_timer = ai_rng.randf_range(0.75, 1.5)

		if not is_on_floor() or distance > 125.0 or opponent.is_attack_active():
			try_jump()


func apply_character_physics(delta):
	if is_on_floor():
		coyote_timer = COYOTE_TIME

		if landed_bounce > 0.0:
			landed_bounce = maxf(landed_bounce - delta, 0.0)
	else:
		velocity.y += GRAVITY * delta

	velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		do_jump()

	var move_direction = 0.0

	if is_player:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_direction -= 1.0

		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_direction += 1.0
	else:
		move_direction = ai_move_direction

	var leg_factor = get_leg_factor()

	if stagger_time > 0.0:
		move_direction *= 0.30

	var target_speed = move_direction * RUN_SPEED * leg_factor

	if move_direction != 0.0:
		var acceleration = RUN_ACCEL

		if not is_on_floor():
			acceleration = AIR_ACCEL

		velocity.x = move_toward(
			velocity.x,
			target_speed,
			acceleration * delta
		)

		run_cycle += absf(velocity.x) * delta * 0.025
	else:
		var deceleration = RUN_DECEL if is_on_floor() else AIR_DECEL

		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

	move_and_slide()

	# Prevent tiny residual motion from making a resting character slide.
	if is_on_floor() and absf(velocity.x) < 3.0:
		velocity.x = 0.0


func do_jump():
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

	velocity.y = -JUMP_SPEED * get_jump_factor()
	landed_bounce = 0.12


func try_jump():
	if defeated:
		return

	jump_buffer_timer = JUMP_BUFFER_TIME

	if coyote_timer > 0.0:
		do_jump()


func get_jump_factor():
	var left = detached["left_leg"]
	var right = detached["right_leg"]

	if left and right:
		return 0.0

	if left or right:
		return 0.82

	return 1.0


func update_pose(delta):
	if not is_on_floor():
		run_cycle += absf(velocity.x) * delta * 0.008

	# Walking animation is deliberately subtle so the physical-looking
	# character stays readable during combat.
	var bob = 0.0

	if is_on_floor() and absf(velocity.x) > 25.0:
		bob = sin(run_cycle) * 2.0

	position.y += bob * delta * 0.0


func get_part_position(part_name):
	var t = clampf(attack_time, 0.0, 1.0)
	var attack_progress = 1.0

	if attack_kind != "":
		var duration = PUNCH_DURATION if attack_kind == "punch" else KICK_DURATION
		attack_progress = 1.0 - attack_time / duration
		attack_progress = clampf(attack_progress, 0.0, 1.0)

	var walk = 0.0

	if is_on_floor() and absf(velocity.x) > 20.0:
		walk = sin(run_cycle) * 5.0

	var dir = facing

	match part_name:
		"head":
			return global_position + Vector2(0.0, -48.0)

		"torso":
			return global_position + Vector2(0.0, 0.0)

		"left_arm":
			if attack_kind == "punch" and dir < 0.0:
				return global_position + Vector2(-40.0 * attack_progress, -3.0)

			return global_position + Vector2(
				-18.0 + walk * 0.35,
				8.0
			)

		"right_arm":
			if attack_kind == "punch" and dir > 0.0:
				return global_position + Vector2(40.0 * attack_progress, -3.0)

			return global_position + Vector2(
				18.0 - walk * 0.35,
				8.0
			)

		"left_leg":
			return global_position + Vector2(
				-10.0 + walk * 0.65,
				46.0 + absf(walk) * 0.15
			)

		"right_leg":
			return global_position + Vector2(
				10.0 - walk * 0.65,
				46.0 + absf(walk) * 0.15
			)

	return global_position


func get_attack_origin(kind):
	var dir = facing

	if kind == "kick":
		return global_position + Vector2(dir * 28.0, 30.0)

	if dir > 0.0:
		return get_part_position("right_arm")

	return get_part_position("left_arm")


func try_attack(kind):
	if defeated or attack_cooldown > 0.0:
		return

	if kind == "punch":
		if detached["left_arm"] and detached["right_arm"]:
			return

		attack_kind = "punch"
		attack_time = PUNCH_DURATION
		attack_cooldown = PUNCH_COOLDOWN

	else:
		if detached["left_leg"] and detached["right_leg"]:
			return

		attack_kind = "kick"
		attack_time = KICK_DURATION
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

	var strength = 420.0 if kind == "punch" else 600.0
	var vertical = -0.10 if kind == "punch" else -0.28
	var damage = 1.0

	if shadow_mode_time > 0.0:
		strength *= 1.42
		damage = 1.35

	var impulse = Vector2(
		direction * strength,
		strength * vertical
	)

	opponent.receive_hit(
		target_name,
		damage,
		impulse,
		kind
	)

	# A small recoil makes attacks feel like bodies transferring momentum.
	velocity.x -= facing * 24.0


func find_attack_target(origin, reach, direction):
	var best = ""
	var best_score = reach

	for part_name in detached.keys():
		if detached[part_name]:
			continue

		var part_position = get_part_position(part_name)
		var offset = part_position - origin
		var distance = offset.length()

		if distance > reach:
			continue

		if offset.x * direction < -12.0:
			continue

		var score = distance

		if part_name == "head":
			score -= 4.0

		if part_name == "torso":
			score -= 2.0

		if score < best_score:
			best_score = score
			best = part_name

	return best


func is_attack_active():
	return attack_kind != "" and attack_time > 0.0


func receive_hit(part_name, damage, impulse, attack_kind_name):
	if defeated:
		return

	if shadow_mode_time > 0.0:
		return

	if not health.has(part_name):
		return

	health[part_name] -= damage

	# CharacterBody2D has no mass property. Scale the incoming impulse into
	# a believable knockback velocity rather than teleporting the character.
	velocity += impulse * HIT_KNOCKBACK * 0.06
	stagger_time = HIT_STAGGER_TIME

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

	var detached_body = LimbScript.new()
	detached_body.name = fighter_name + "_Detached_" + part_name
	owner_game.arena_root.add_child(detached_body)
	detached_body.global_position = get_part_position(part_name)

	var size = Vector2(8.0, 42.0)
	var kind = "rect"

	match part_name:
		"head":
			size = Vector2(14.0, 14.0)
			kind = "circle"

		"torso":
			size = Vector2(14.0, 48.0)

		"left_leg", "right_leg":
			size = Vector2(8.0, 42.0)

	detached_body.setup(
		part_name,
		size,
		base_color,
		accent_color,
		kind
	)

	detached_body.collision_layer = 4
	detached_body.collision_mask = 3

	detached_body.linear_velocity = velocity
	detached_body.angular_velocity = facing * 3.0

	var burst = Vector2(
		facing * 100.0,
		-125.0
	)

	detached_body.apply_central_impulse(burst)

	owner_game.call("part_lost", self, part_name)

	if part_name == "head" or part_name == "torso":
		defeated = true
	elif get_detached_count() >= 4:
		defeated = true

	if defeated:
		velocity = Vector2.ZERO
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
		return 0.38

	if left_lost or right_lost:
		return 0.70

	return 1.0


func can_shadow_mode():
	return (
		shadow_mode_cooldown <= 0.0
		and shadow_mode_time <= 0.0
		and not defeated
	)


func try_shadow_mode():
	if not can_shadow_mode():
		return

	shadow_mode_time = SHADOW_DURATION
	shadow_mode_cooldown = SHADOW_COOLDOWN
	set_shadow_visual(true)

	owner_game.call(
		"shadow_mode_started",
		self
	)


func set_shadow_visual(value):
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


func _draw():
	var body_color = base_color
	var line_color = accent_color

	if shadow_mode_time > 0.0:
		body_color = Color("#efeaff")
		line_color = Color("#c9b5ff")

	if stagger_time > 0.0:
		line_color = Color("#ffffff")

	var bob = 0.0

	if is_on_floor() and absf(velocity.x) > 25.0:
		bob = sin(run_cycle * 0.75) * 1.5

	var root = Vector2(0.0, bob)

	# Head.
	if not detached["head"]:
		draw_circle(root + Vector2(0, -48), 14.0, body_color)
		draw_arc(
			root + Vector2(0, -48),
			14.0,
			0.0,
			TAU,
			28,
			line_color,
			2.0
		)

	# Simple face direction indicator.
	if not detached["head"]:
		draw_circle(
			root + Vector2(facing * 5.0, -50.0),
			2.0,
			line_color
		)

	# Torso.
	if not detached["torso"]:
		draw_line(
			root + Vector2(0, -31),
			root + Vector2(0, 17),
			body_color,
			9.0,
			true
		)

	# Arms.
	if not detached["left_arm"]:
		var left_hand = get_part_position("left_arm") - global_position + root
		draw_line(
			root + Vector2(-9, -20),
			left_hand,
			body_color,
			7.0,
			true
		)
		draw_circle(left_hand, 4.0, body_color)

	if not detached["right_arm"]:
		var right_hand = get_part_position("right_arm") - global_position + root
		draw_line(
			root + Vector2(9, -20),
			right_hand,
			body_color,
			7.0,
			true
		)
		draw_circle(right_hand, 4.0, body_color)

	# Legs.
	if not detached["left_leg"]:
		var left_foot = get_part_position("left_leg") - global_position + root
		draw_line(
			root + Vector2(-6, 17),
			left_foot,
			body_color,
			8.0,
			true
		)
		draw_line(
			left_foot,
			left_foot + Vector2(-4, 13),
			body_color,
			7.0,
			true
		)

	if not detached["right_leg"]:
		var right_foot = get_part_position("right_leg") - global_position + root
		draw_line(
			root + Vector2(6, 17),
			right_foot,
			body_color,
			8.0,
			true
		)
		draw_line(
			right_foot,
			right_foot + Vector2(4, 13),
			body_color,
			7.0,
			true
		)

	# Small shadow below the fighter makes grounded contact easier to read.
	if is_on_floor():
		draw_ellipse(Vector2(0, 61), Vector2(20, 5), Color(0, 0, 0, 0.24))


func draw_ellipse(center, radii, color):
	var points = PackedVector2Array()

	for i in range(25):
		var angle = TAU * float(i) / 24.0
		points.append(
			center + Vector2(
				cos(angle) * radii.x,
				sin(angle) * radii.y
			)
		)

	draw_colored_polygon(points, color)
