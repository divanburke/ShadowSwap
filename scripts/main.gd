extends Node2D

const FighterScript = preload("res://scripts/fighter.gd")
const PlatformScript = preload("res://scripts/arena_platform.gd")

const VIEW_SIZE = Vector2(1152, 648)

var player
var ai
var arena_root

var ui_layer
var player_label
var ai_label
var player_parts
var ai_parts
var player_shadow
var ai_shadow
var center_message
var event_message
var round_message
var instruction_label

var round_over = false
var reset_count = 0
var event_message_time = 0.0
var center_message_time = 0.0
var pulse_time = 0.0


func _ready():
	build_arena()
	build_ui()
	start_round()


func start_round():
	if player != null and is_instance_valid(player):
		player.free()

	if ai != null and is_instance_valid(ai):
		ai.free()

	player = FighterScript.new()
	player.name = "PlayerFighter"
	arena_root.add_child(player)
	player.setup(
		self,
		"PLAYER",
		true,
		Vector2(270, 505),
		Color("#f4f7ff"),
		Color("#55d6ff")
	)

	ai = FighterScript.new()
	ai.name = "AIFighter"
	arena_root.add_child(ai)
	ai.setup(
		self,
		"AI",
		false,
		Vector2(882, 505),
		Color("#e4d9ff"),
		Color("#b993ff")
	)

	round_over = false
	round_message.text = "FIGHT!"
	center_message_time = 0.9
	update_ui()


func build_arena():
	arena_root = Node2D.new()
	arena_root.name = "Arena"
	add_child(arena_root)

	create_platform(Vector2(576, 610), Vector2(1152, 76))
	create_platform(Vector2(210, 430), Vector2(230, 24))
	create_platform(Vector2(942, 430), Vector2(230, 24))
	create_platform(Vector2(576, 360), Vector2(170, 24))
	create_platform(Vector2(370, 285), Vector2(150, 22))
	create_platform(Vector2(782, 285), Vector2(150, 22))

	# Short side walls keep the fight inside the arena.
	create_platform(Vector2(10, 330), Vector2(20, 560))
	create_platform(Vector2(1142, 330), Vector2(20, 560))


func create_platform(platform_position, platform_size):
	var platform = PlatformScript.new()
	platform.position = platform_position
	arena_root.add_child(platform)

	var fill = Color("#2b303a")
	var border = Color("#46505f")

	platform.setup(platform_size, fill, border)


func build_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	var top = ColorRect.new()
	top.position = Vector2(22, 20)
	top.size = Vector2(1108, 95)
	top.color = Color(0.035, 0.045, 0.065, 0.94)
	ui_layer.add_child(top)

	var title = Label.new()
	title.position = Vector2(44, 32)
	title.text = "SHADOWSWAP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f4f7ff"))
	ui_layer.add_child(title)

	var subtitle = Label.new()
	subtitle.position = Vector2(46, 69)
	subtitle.text = "STICK FIGHT PHYSICS  |  BUILD 03"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("#7f8b9e"))
	ui_layer.add_child(subtitle)

	player_label = Label.new()
	player_label.position = Vector2(285, 35)
	player_label.size = Vector2(235, 24)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(player_label)

	ai_label = Label.new()
	ai_label.position = Vector2(632, 35)
	ai_label.size = Vector2(235, 24)
	ai_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_label.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(ai_label)

	player_parts = Label.new()
	player_parts.position = Vector2(285, 64)
	player_parts.size = Vector2(235, 24)
	player_parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_parts.add_theme_font_size_override("font_size", 10)
	player_parts.add_theme_color_override("font_color", Color("#8d99ad"))
	ui_layer.add_child(player_parts)

	ai_parts = Label.new()
	ai_parts.position = Vector2(632, 64)
	ai_parts.size = Vector2(235, 24)
	ai_parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_parts.add_theme_font_size_override("font_size", 10)
	ai_parts.add_theme_color_override("font_color", Color("#8d99ad"))
	ui_layer.add_child(ai_parts)

	player_shadow = Label.new()
	player_shadow.position = Vector2(285, 88)
	player_shadow.size = Vector2(235, 18)
	player_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_shadow.add_theme_font_size_override("font_size", 10)
	ui_layer.add_child(player_shadow)

	ai_shadow = Label.new()
	ai_shadow.position = Vector2(632, 88)
	ai_shadow.size = Vector2(235, 18)
	ai_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_shadow.add_theme_font_size_override("font_size", 10)
	ui_layer.add_child(ai_shadow)

	instruction_label = Label.new()
	instruction_label.position = Vector2(48, 572)
	instruction_label.size = Vector2(1056, 28)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.text = "A / D or ARROWS MOVE     UP / W JUMP     J PUNCH     K KICK     E SHADOW MODE     R RESET"
	instruction_label.add_theme_font_size_override("font_size", 11)
	instruction_label.add_theme_color_override("font_color", Color("#8d99ad"))
	ui_layer.add_child(instruction_label)

	center_message = Label.new()
	center_message.position = Vector2(330, 135)
	center_message.size = Vector2(492, 60)
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.add_theme_font_size_override("font_size", 34)
	center_message.add_theme_color_override("font_color", Color("#f4f7ff"))
	ui_layer.add_child(center_message)

	event_message = Label.new()
	event_message.position = Vector2(370, 200)
	event_message.size = Vector2(412, 28)
	event_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_message.add_theme_font_size_override("font_size", 14)
	event_message.add_theme_color_override("font_color", Color("#bfc9d8"))
	ui_layer.add_child(event_message)

	round_message = Label.new()
	round_message.position = Vector2(46, 121)
	round_message.size = Vector2(1060, 30)
	round_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_message.add_theme_font_size_override("font_size", 14)
	round_message.add_theme_color_override("font_color", Color("#7f8b9e"))
	round_message.text = ""
	ui_layer.add_child(round_message)


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_count += 1
			start_round()


func get_opponent(fighter):
	if fighter == player:
		return ai
	return player


func report_hit(attacker_name, part_name, attack_kind):
	var pretty = part_name.replace("_", " ").to_upper()
	event_message.text = attacker_name + "  •  " + attack_kind.to_upper() + "  •  " + pretty
	event_message_time = 0.7


func part_lost(fighter, part_name):
	var side = fighter.fighter_name
	var pretty = part_name.replace("_", " ").to_upper()

	event_message.text = side + " LOST " + pretty
	event_message_time = 1.15

	if part_name == "left_leg" or part_name == "right_leg":
		center_message.text = "MOVEMENT DAMAGED"
		center_message_time = 0.7

	if part_name == "left_arm" or part_name == "right_arm":
		center_message.text = "ATTACK RANGE CHANGED"
		center_message_time = 0.7


func shadow_mode_started(fighter):
	var side = fighter.fighter_name
	event_message.text = side + " ENTERED SHADOW MODE"
	event_message_time = 1.2
	center_message.text = "SHADOW MODE"
	center_message_time = 0.9


func fighter_defeated(loser):
	if round_over:
		return

	round_over = true

	var winner = get_opponent(loser)

	if winner == player:
		center_message.text = "YOU WIN"
		event_message.text = "THE AI FIGHTER WAS KNOCKED APART"
	else:
		center_message.text = "AI WINS"
		event_message.text = "YOUR FIGHTER WAS KNOCKED APART"

	center_message_time = 999.0
	event_message_time = 999.0
	round_message.text = "PRESS R TO FIGHT AGAIN"


func update_ui():
	if player == null or ai == null:
		return

	player_label.text = "PLAYER"
	ai_label.text = "AI"

	player_label.add_theme_color_override("font_color", Color("#55d6ff"))
	ai_label.add_theme_color_override("font_color", Color("#b993ff"))

	player_parts.text = player.get_status_text()
	ai_parts.text = ai.get_status_text()

	player_shadow.text = "SHADOW: " + player.get_shadow_status()
	ai_shadow.text = "SHADOW: " + ai.get_shadow_status()

	if player.shadow_mode_time > 0.0:
		player_shadow.add_theme_color_override("font_color", Color("#c9b5ff"))
	else:
		player_shadow.add_theme_color_override("font_color", Color("#7f8b9e"))

	if ai.shadow_mode_time > 0.0:
		ai_shadow.add_theme_color_override("font_color", Color("#c9b5ff"))
	else:
		ai_shadow.add_theme_color_override("font_color", Color("#7f8b9e"))


func _process(delta):
	pulse_time += delta

	if event_message_time < 900.0:
		event_message_time = maxf(event_message_time - delta, 0.0)
		if event_message_time <= 0.0:
			event_message.text = ""

	if center_message_time < 900.0:
		center_message_time = maxf(center_message_time - delta, 0.0)
		if center_message_time <= 0.0:
			center_message.text = ""

	update_ui()
	queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#090c12"))

	# Subtle arena split.
	draw_rect(
		Rect2(0, 115, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 115),
		Color(0.04, 0.07, 0.10, 0.50)
	)

	draw_rect(
		Rect2(VIEW_SIZE.x / 2.0, 115, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 115),
		Color(0.09, 0.06, 0.13, 0.50)
	)

	for x in range(0, int(VIEW_SIZE.x) + 1, 48):
		draw_line(
			Vector2(x, 116),
			Vector2(x, VIEW_SIZE.y),
			Color(1, 1, 1, 0.018),
			1.0
		)

	for y in range(120, int(VIEW_SIZE.y) + 1, 48):
		draw_line(
			Vector2(0, y),
			Vector2(VIEW_SIZE.x, y),
			Color(1, 1, 1, 0.018),
			1.0
		)

	var pulse = 1.0 + sin(pulse_time * 2.5) * 0.05

	draw_circle(Vector2(576, 235), 120.0 * pulse, Color(0.33, 0.84, 1.0, 0.015))
	draw_arc(
		Vector2(576, 235),
		92.0 * pulse,
		0.0,
		TAU,
		64,
		Color(0.33, 0.84, 1.0, 0.06),
		1.0
	)

	draw_line(
		Vector2(48, 548),
		Vector2(1104, 548),
		Color(1, 1, 1, 0.05),
		1.0
	)
