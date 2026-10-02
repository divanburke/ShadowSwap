extends CharacterBody2D

# ShadowSwap fighter
# A stable physics-aware stick fighter designed around short arena matches.
# The attached body is one controllable character; attacks transfer momentum.
# There is deliberately no weapon system in this build.

const COLLISION_RADIUS = 13.0
const COLLISION_HEIGHT = 82.0

const RUN_SPEED = 330.0
const RUN_ACCEL = 2400.0
const RUN_DECEL = 2700.0
const AIR_ACCEL = 1050.0
const AIR_DECEL = 500.0

const GRAVITY = 1750.0
const MAX_FALL_SPEED = 1050.0
const JUMP_SPEED = 610.0
const COYOTE_TIME = 0.10
const JUMP_BUFFER = 0.12

const PUNCH_RANGE = 68.0
const KICK_RANGE = 82.0
const PUNCH_FORCE = 520.0
const KICK_FORCE = 680.0

const PUNCH_DURATION = 0.16
const KICK_DURATION = 0.22
const PUNCH_COOLDOWN = 0.28
const KICK_COOLDOWN = 0.40
const HIT_STUN = 0.14

var owner_game
var fighter_name = "PLAYER"
var is_player = true
var base_color = Color.WHITE
var controls = {
	"left": KEY_A,
	"right": KEY_D,
	"jump": KEY_W,
	"punch": KEY_J,
	"kick": KEY_K
}

var facing = 1.0
var defeated = false

var attack_kind = ""
var attack_timer = 0.0
var attack_cooldown = 0.0
var hit_stun_timer = 0.0

var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var was_on_floor = false

var walk_phase = 0.0
var ai_timer = 0.0
var ai_jump_timer = 0.0
var ai_move = 0.0
var ai_enabled = true
var rng = RandomNumberGenerator.new()


func setup(game, display_name, player_control, start_position, p_color, _p_accent):
	owner_game = game
	fighter_name = display_name
	is_player = player_control
	base_color = p_color
	global_position = start_position

	rng.randomize()

	collision_layer = 2
	collision_mask = 3
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

	floor_stop_on_slope = true
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.08

	build_collision()
	queue_redraw()


func set_ai_enabled(value):
	ai_enabled = value


func build_collision():
	var collision = CollisionShape2D.new()
	collision.name = "FighterCollision"

	var capsule = CapsuleShape2D.new()
	capsule.radius = COLLISION_RADIUS
	capsule.height = COLLISION_HEIGHT

	collision.shape = capsule
	collision.position = Vector2(0.0, 2.0)

	add_child(collision)


func _physics_process(delta):
	if defeated:
		return

	update_timers(delta)

	if is_player:
		read_player_input()
	elif ai_enabled:
		update_ai(delta)
	else:
		ai_move = 0.0

	update_movement(delta)
	update_animation(delta)

	queue_redraw()


func update_timers(delta):
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	hit_stun_timer = maxf(hit_stun_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if attack_timer > 0.0:
		attack_timer -= delta

		if attack_timer <= 0.0:
			attack_timer = 0.0
			attack_kind = ""


func read_player_input():
	var move = 0.0

	if Input.is_key_pressed(controls["left"]) or Input.is_key_pressed(KEY_LEFT):
		move -= 1.0

	if Input.is_key_pressed(controls["right"]) or Input.is_key_pressed(KEY_RIGHT):
		move += 1.0

	if move != 0.0:
		facing = move

	var jump_down = Input.is_key_pressed(controls["jump"]) or Input.is_key_pressed(KEY_UP)
	var punch_down = Input.is_key_pressed(controls["punch"])
	var kick_down = Input.is_key_pressed(controls["kick"])

	if jump_down and not _jump_down_last_frame:
		jump_buffer_timer = JUMP_BUFFER

	if punch_down and not _punch_down_last_frame:
		try_attack("punch")

	if kick_down and not _kick_down_last_frame:
		try_attack("kick")

	if not jump_down and _jump_down_last_frame and velocity.y < -180.0:
		velocity.y *= 0.48

	_jump_down_last_frame = jump_down
	_punch_down_last_frame = punch_down
	_kick_down_last_frame = kick_down

	player_move = move


var player_move = 0.0
var _jump_down_last_frame = false
var _punch_down_last_frame = false
var _kick_down_last_frame = false


func update_ai(delta):
	var opponent = owner_game.call("get_opponent", self)

	if opponent == null or opponent.defeated:
		ai_move = 0.0
		return

	var dx = opponent.global_position.x - global_position.x
	var distance = absf(dx)

	if absf(dx) > 5.0:
		facing = sign(dx)

	ai_timer -= delta
	ai_jump_timer -= delta

	if ai_timer > 0.0:
		return

	ai_timer = rng.randf_range(0.08, 0.16)

	var desired = sign(dx)

	if distance < 110.0 and rng.randf() < 0.16:
		desired *= -1.0

	ai_move = desired

	if attack_cooldown <= 0.0 and distance < KICK_RANGE + 12.0:
		try_attack("punch" if rng.randf() < 0.55 else "kick")

	if ai_jump_timer <= 0.0 and rng.randf() < 0.18:
		ai_jump_timer = rng.randf_range(0.7, 1.4)

		if distance > 120.0 or opponent.is_attack_active():
			try_jump()


func update_movement(delta):
	var move_direction = player_move if is_player else ai_move

	if hit_stun_timer > 0.0:
		move_direction *= 0.25

	var leg_factor = 1.0
	var target_speed = move_direction * RUN_SPEED * leg_factor

	if move_direction != 0.0:
		var accel = RUN_ACCEL if is_on_floor() else AIR_ACCEL

		velocity.x = move_toward(
			velocity.x,
			target_speed,
			accel * delta
		)
	else:
		var decel = RUN_DECEL if is_on_floor() else AIR_DECEL

		velocity.x = move_toward(
			velocity.x,
			0.0,
			decel * delta
		)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		coyote_timer = COYOTE_TIME

	if was_on_floor and not is_on_floor() and velocity.y >= 0.0:
		coyote_timer = COYOTE_TIME

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		do_jump()

	velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	move_and_slide()

	was_on_floor = is_on_floor()

	if is_on_floor() and absf(velocity.x) < 2.0:
		velocity.x = 0.0


func do_jump():
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.y = -JUMP_SPEED


func try_jump():
	if defeated:
		return

	jump_buffer_timer = JUMP_BUFFER

	if coyote_timer > 0.0 or is_on_floor():
		do_jump()


func try_attack(kind):
	if defeated or attack_cooldown > 0.0 or hit_stun_timer > 0.0:
		return

	if kind == "punch":
		attack_kind = "punch"
		attack_timer = PUNCH_DURATION
		attack_cooldown = PUNCH_COOLDOWN
	else:
		attack_kind = "kick"
		attack_timer = KICK_DURATION
		attack_cooldown = KICK_COOLDOWN

	var opponent = owner_game.call("get_opponent", self)

	if opponent == null or opponent.defeated:
		return

	var origin = get_attack_origin()
	var range = PUNCH_RANGE if kind == "punch" else KICK_RANGE

	if not opponent.is_attack_target(origin, range, facing):
		return

	var force = PUNCH_FORCE if kind == "punch" else KICK_FORCE
	var lift = -125.0 if kind == "punch" else -220.0

	if opponent.global_position.y < global_position.y - 25.0:
		lift = -80.0

	opponent.receive_attack_hit(
		Vector2(
			facing * force,
			lift
		),
		kind
	)

	# Attacker also gets a small physical reaction.
	velocity.x -= facing * 28.0


func get_attack_origin():
	if attack_kind == "kick":
		return global_position + Vector2(facing * 28.0, 30.0)

	return global_position + Vector2(facing * 28.0, -10.0)


func is_attack_target(origin, range, direction):
	var target = global_position + Vector2(0.0, -18.0)
	var offset = target - origin
	var distance = offset.length()

	if distance > range:
		return false

	if offset.x * direction < -8.0:
		return false

	return true


func receive_attack_hit(impact, _kind):
	if defeated:
		return

	velocity += impact * 0.14
	hit_stun_timer = HIT_STUN


func is_attack_active():
	return attack_kind != "" and attack_timer > 0.0


func update_animation(delta):
	var speed_ratio = clampf(absf(velocity.x) / RUN_SPEED, 0.0, 1.0)

	if is_on_floor() and speed_ratio > 0.05:
		walk_phase += delta * (5.0 + speed_ratio * 10.0)


func get_pose_point(part):
	var walk = sin(walk_phase)
	var opposite = sin(walk_phase + PI)
	var jump_amount = clampf(-velocity.y / JUMP_SPEED, -0.25, 0.85)
	var punch = 0.0

	if attack_kind == "punch":
		var progress = 1.0 - attack_timer / PUNCH_DURATION
		punch = sin(clampf(progress, 0.0, 1.0) * PI)

	match part:
		"head":
			return Vector2(0.0, -50.0 - jump_amount * 2.0)

		"shoulder_l":
			return Vector2(-9.0, -25.0)

		"shoulder_r":
			return Vector2(9.0, -25.0)

		"hand_l":
			if attack_kind == "punch" and facing < 0.0:
				return Vector2(-15.0 - 32.0 * punch, -24.0)
			return Vector2(-21.0 - walk * 4.0, -2.0 + opposite * 3.0)

		"hand_r":
			if attack_kind == "punch" and facing > 0.0:
				return Vector2(15.0 + 32.0 * punch, -24.0)
			return Vector2(21.0 + walk * 4.0, -2.0 + walk * 3.0)

		"knee_l":
			return Vector2(-7.0 - walk * 5.0, 25.0)

		"knee_r":
			return Vector2(7.0 + walk * 5.0, 25.0)

		"foot_l":
			return Vector2(-10.0 + walk * 8.0, 48.0)

		"foot_r":
			return Vector2(10.0 - walk * 8.0, 48.0)

	return Vector2.ZERO


func _draw():
	var color = base_color

	if hit_stun_timer > 0.0:
		color = Color.WHITE

	var head = get_pose_point("head")
	var shoulder_l = get_pose_point("shoulder_l")
	var shoulder_r = get_pose_point("shoulder_r")
	var hand_l = get_pose_point("hand_l")
	var hand_r = get_pose_point("hand_r")
	var knee_l = get_pose_point("knee_l")
	var knee_r = get_pose_point("knee_r")
	var foot_l = get_pose_point("foot_l")
	var foot_r = get_pose_point("foot_r")

	if not defeated:
		draw_circle(head, 14.0, color)

		draw_pill(Vector2(0.0, -30.0), Vector2(0.0, 15.0), 10.0, color)

		draw_pill(shoulder_l, hand_l, 7.0, color)
		draw_pill(shoulder_r, hand_r, 7.0, color)

		draw_pill(Vector2(-5.0, 15.0), knee_l, 8.0, color)
		draw_pill(knee_l, foot_l, 8.0, color)

		draw_pill(Vector2(5.0, 15.0), knee_r, 8.0, color)
		draw_pill(knee_r, foot_r, 8.0, color)


func draw_pill(a, b, width, color):
	var radius = width * 0.5

	draw_line(
		a,
		b,
		color,
		width,
		true
	)

	draw_circle(a, radius, color)
	draw_circle(b, radius, color)


func mark_defeated():
	if defeated:
		return

	defeated = true
	velocity = Vector2.ZERO
	queue_redraw()
