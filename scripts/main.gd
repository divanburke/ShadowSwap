extends Node2D

const FighterScript = preload("res://scripts/fighter.gd")
const PlatformScript = preload("res://scripts/arena_platform.gd")

const VIEW_SIZE = Vector2(1152, 648)

# AI is deliberately disabled for the current build.
const AI_ENABLED = false

var player_one
var player_two
var arena_root

var ui_layer
var title_label
var mode_label
var p1_label
var p2_label
var round_label
var center_message
var hint_label

var p1_score = 0
var p2_score = 0
var round_number = 1
var round_locked = false
var restart_timer = 0.0
var arena_layout = 0


func _ready():
	build_ui()
	start_round()


func start_round():
	round_locked = false
	restart_timer = 0.0

	if player_one != null and is_instance_valid(player_one):
		player_one.queue_free()

	if player_two != null and is_instance_valid(player_two):
		player_two.queue_free()

	build_arena()

	player_one = FighterScript.new()
	player_one.name = "PlayerOne"
	arena_root.add_child(player_one)
	player_one.setup(
		self,
		"P1",
		true,
		Vector2(300, 510),
		Color("#4fe3b1"),
		Color.WHITE,
		1
	)

	player_two = FighterScript.new()
	player_two.name = "PlayerTwo"
	arena_root.add_child(player_two)
	player_two.setup(
		self,
		"P2",
		true,
		Vector2(852, 510),
		Color("#ff718f"),
		Color.WHITE,
		2
	)

	# The AI branch remains available in the fighter script, but it is
	# intentionally disabled while the movement/combat foundation is tested.
	player_two.set_ai_enabled(false)

	center_message.text = "ROUND %02d" % round_number
	center_message.modulate.a = 1.0

	round_label.text = "ROUND %02d   •   FIRST TO 5" % round_number
	update_score_ui()


func build_arena():
	if arena_root != null and is_instance_valid(arena_root):
		arena_root.queue_free()

	arena_root = Node2D.new()
	arena_root.name = "Arena"
	add_child(arena_root)

	# Cycle through compact platform layouts to give the match the
	# unpredictable arena feel of a physics platform fighter.
	arena_layout = (round_number - 1) % 4

	match arena_layout:
		0:
			create_platform(Vector2(576, 620), Vector2(1152, 56))
			create_platform(Vector2(360, 470), Vector2(260, 24))
			create_platform(Vector2(792, 470), Vector2(260, 24))
			create_platform(Vector2(576, 350), Vector2(190, 24))

		1:
			create_platform(Vector2(576, 620), Vector2(1152, 56))
			create_platform(Vector2(250, 485), Vector2(200, 24))
			create_platform(Vector2(576, 405), Vector2(210, 24))
			create_platform(Vector2(902, 485), Vector2(200, 24))
			create_platform(Vector2(576, 265), Vector2(130, 22))

		2:
			create_platform(Vector2(576, 620), Vector2(1152, 56))
			create_platform(Vector2(175, 455), Vector2(170, 24))
			create_platform(Vector2(390, 330), Vector2(180, 24))
			create_platform(Vector2(762, 330), Vector2(180, 24))
			create_platform(Vector2(977, 455), Vector2(170, 24))

		3:
			create_platform(Vector2(576, 620), Vector2(1152, 56))
			create_platform(Vector2(300, 460), Vector2(220, 24))
			create_platform(Vector2(852, 460), Vector2(220, 24))
			create_platform(Vector2(576, 340), Vector2(120, 24))
			create_platform(Vector2(576, 210), Vector2(150, 22))


func create_platform(platform_position, platform_size):
	var platform = PlatformScript.new()
	platform.position = platform_position
	arena_root.add_child(platform)

	platform.setup(
		platform_size,
		Color("#303845"),
		Color("#4d5969")
	)


func build_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	var top = ColorRect.new()
	top.position = Vector2(18, 18)
	top.size = Vector2(1116, 96)
	top.color = Color("#11161d")
	ui_layer.add_child(top)

	title_label = Label.new()
	title_label.position = Vector2(38, 28)
	title_label.text = "SHADOWSWAP"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override(
		"font_color",
		Color("#f4f7ff")
	)
	ui_layer.add_child(title_label)

	mode_label = Label.new()
	mode_label.position = Vector2(40, 65)
	mode_label.text = "PHYSICS STICK FIGHT  •  LOCAL TEST"
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override(
		"font_color",
		Color("#7e8998")
	)
	ui_layer.add_child(mode_label)

	p1_label = Label.new()
	p1_label.position = Vector2(290, 31)
	p1_label.size = Vector2(220, 28)
	p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(p1_label)

	p2_label = Label.new()
	p2_label.position = Vector2(642, 31)
	p2_label.size = Vector2(220, 28)
	p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(p2_label)

	round_label = Label.new()
	round_label.position = Vector2(280, 74)
	round_label.size = Vector2(592, 22)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 11)
	round_label.add_theme_color_override(
		"font_color",
		Color("#8e99a9")
	)
	ui_layer.add_child(round_label)

	center_message = Label.new()
	center_message.position = Vector2(316, 130)
	center_message.size = Vector2(520, 70)
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.add_theme_font_size_override("font_size", 38)
	center_message.add_theme_color_override(
		"font_color",
		Color("#f4f7ff")
	)
	ui_layer.add_child(center_message)

	hint_label = Label.new()
	hint_label.position = Vector2(45, 573)
	hint_label.size = Vector2(1062, 28)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text = "P1  A / D + W + J / K      P2  ← / → + ↑ + , / .      R  NEW ROUND"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override(
		"font_color",
		Color("#8e99a9")
	)
	ui_layer.add_child(hint_label)


func update_score_ui():
	p1_label.text = "P1   %d" % p1_score
	p2_label.text = "%d   P2" % p2_score

	p1_label.add_theme_color_override(
		"font_color",
		Color("#4fe3b1")
	)

	p2_label.add_theme_color_override(
		"font_color",
		Color("#ff718f")
	)


func get_opponent(fighter):
	if fighter == player_one:
		return player_two

	return player_one


func report_hit(attacker_name, _part_name, attack_kind):
	center_message.text = attacker_name + "  " + attack_kind.to_upper()
	center_message.modulate.a = 1.0


func part_lost(_fighter, _part_name):
	# Kept for compatibility with older project code. The new Stick Fight
	# style no longer uses detachable body-part health.
	pass


func shadow_mode_started(_fighter):
	# Kept for compatibility with the previous prototype. Shadow abilities
	# are disabled in this gameplay reset.
	pass


func fighter_defeated(loser):
	if round_locked:
		return

	round_locked = true

	var winner = get_opponent(loser)

	if winner == player_one:
		p1_score += 1
		center_message.text = "P1 WINS"
	else:
		p2_score += 1
		center_message.text = "P2 WINS"

	update_score_ui()

	if p1_score >= 5 or p2_score >= 5:
		center_message.text += "\nMATCH OVER"
		round_label.text = "PRESS R TO START A NEW MATCH"
	else:
		round_label.text = "PRESS R FOR NEXT ROUND"


func _input(event):
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_R:
		if p1_score >= 5 or p2_score >= 5:
			p1_score = 0
			p2_score = 0
			round_number = 1
		else:
			round_number += 1

		start_round()


func _process(delta):
	if center_message.modulate.a < 0.98 and center_message.text != "":
		center_message.modulate.a = move_toward(
			center_message.modulate.a,
			1.0,
			delta * 5.0
		)

	# Falling outside the screen ends a round.
	if not round_locked:
		if player_one != null and is_instance_valid(player_one):
			if player_one.global_position.y > 720.0:
				player_one.mark_defeated()
				fighter_defeated(player_one)

		if player_two != null and is_instance_valid(player_two):
			if player_two.global_position.y > 720.0:
				player_two.mark_defeated()
				fighter_defeated(player_two)

	queue_redraw()


func _draw():
	draw_rect(
		Rect2(Vector2.ZERO, VIEW_SIZE),
		Color("#0a0e13")
	)

	# Flat, simple backdrop.
	draw_rect(
		Rect2(0, 114, VIEW_SIZE.x, VIEW_SIZE.y - 114),
		Color("#151b23")
	)

	# Soft horizontal bands give the arena depth without busy textures.
	for y in range(150, 570, 52):
		draw_line(
			Vector2(0, y),
			Vector2(VIEW_SIZE.x, y),
			Color(1, 1, 1, 0.025),
			1.0
		)

	# Arena center marker.
	draw_line(
		Vector2(576, 145),
		Vector2(576, 552),
		Color(1, 1, 1, 0.025),
		1.0
	)
