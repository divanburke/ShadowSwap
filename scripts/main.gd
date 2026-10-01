extends Node2D

const CharacterScript = preload("res://scripts/character.gd")

const VIEW_SIZE = Vector2(1152, 648)
const PLAYER_START = Vector2(140, 535)
const SHADOW_START = Vector2(1012, 535)

const REAL_WORLD = 1
const SHADOW_WORLD = 2
const COMMON_LAYER = 3

var player
var shadow
var active_character

var goal_position = Vector2(576, 118)
var goal_area

var status_label
var active_label
var message_label
var win_panel
var win_title
var win_subtitle

var swap_flash = 0.0
var message_time = 0.0
var swap_count = 0
var reset_count = 0
var game_won = false
var last_swap_midpoint = Vector2.ZERO


func _ready():
	build_level()
	build_characters()
	build_ui()
	active_character = player
	update_ui()
	queue_redraw()


func build_level():
	create_platform("Ground", Vector2(576, 610), Vector2(1152, 76), COMMON_LAYER, Color("#262b36"), Color("#3a4252"))

	create_platform("RealStep1", Vector2(210, 500), Vector2(170, 22), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("RealStep2", Vector2(270, 415), Vector2(150, 22), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("RealStep3", Vector2(140, 320), Vector2(100, 22), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))

	create_platform("ShadowStep1", Vector2(942, 500), Vector2(170, 22), SHADOW_WORLD, Color("#332a48"), Color("#b993ff"))
	create_platform("ShadowStep2", Vector2(882, 415), Vector2(150, 22), SHADOW_WORLD, Color("#332a48"), Color("#b993ff"))
	create_platform("ShadowStep3", Vector2(900, 320), Vector2(160, 22), SHADOW_WORLD, Color("#332a48"), Color("#b993ff"))

	create_platform("Center", Vector2(576, 245), Vector2(250, 24), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))
	create_platform("GoalPlatform", Vector2(576, 145), Vector2(180, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))

	create_goal()


func create_platform(platform_name, platform_position, platform_size, layer, fill_color, border_color):
	var platform = StaticBody2D.new()
	platform.name = platform_name
	platform.position = platform_position
	platform.collision_layer = layer
	platform.collision_mask = 0
	add_child(platform)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	platform.add_child(collision)

	var visual = Polygon2D.new()
	var half = platform_size / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	visual.color = fill_color
	platform.add_child(visual)

	var outline = Line2D.new()
	outline.width = 2.0
	outline.default_color = border_color
	outline.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y)
	])
	platform.add_child(outline)


func build_characters():
	player = CharacterScript.new()
	player.name = "Player"
	add_child(player)
	player.setup(self, false, PLAYER_START, REAL_WORLD, Color("#f4f7ff"), Color("#55d6ff"), "REAL")

	shadow = CharacterScript.new()
	shadow.name = "Shadow"
	add_child(shadow)
	shadow.setup(self, true, SHADOW_START, SHADOW_WORLD, Color("#d7c7ff"), Color("#b993ff"), "SHADOW")


func create_goal():
	goal_area = Area2D.new()
	goal_area.name = "Goal"
	goal_area.position = goal_position
	goal_area.collision_layer = 16
	goal_area.collision_mask = 4
	add_child(goal_area)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 70)
	collision.shape = shape
	goal_area.add_child(collision)

	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-34, 30),
		Vector2(-34, -20),
		Vector2(34, -20),
		Vector2(34, 30)
	])
	visual.color = Color("#55d6ff")
	goal_area.add_child(visual)

	var glow = Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-46, 38),
		Vector2(-46, -30),
		Vector2(46, -30),
		Vector2(46, 38)
	])
	glow.color = Color(0.33, 0.84, 1.0, 0.08)
	glow.z_index = -1
	goal_area.add_child(glow)

	goal_area.body_entered.connect(_on_goal_body_entered)


func build_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var top_bar = ColorRect.new()
	top_bar.position = Vector2(28, 22)
	top_bar.size = Vector2(1096, 84)
	top_bar.color = Color(0.04, 0.05, 0.08, 0.92)
	canvas.add_child(top_bar)

	var title = Label.new()
	title.position = Vector2(48, 31)
	title.text = "SHADOW SWAP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(title)

	var subtitle = Label.new()
	subtitle.position = Vector2(50, 69)
	subtitle.text = "BUILD 01  |  FIND A POSITION  |  SWAP WORLDS"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(subtitle)

	active_label = Label.new()
	active_label.position = Vector2(650, 36)
	active_label.size = Vector2(235, 24)
	active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	active_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(active_label)

	var controls = Label.new()
	controls.position = Vector2(895, 31)
	controls.size = Vector2(205, 60)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.text = "A / D or ARROWS  MOVE\nSPACE  JUMP\nTAB  CONTROL  |  Q  SWAP\nR  RESET"
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(controls)

	message_label = Label.new()
	message_label.position = Vector2(390, 116)
	message_label.size = Vector2(372, 38)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(message_label)

	status_label = Label.new()
	status_label.position = Vector2(48, 570)
	status_label.size = Vector2(1056, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("#aeb9ca"))
	canvas.add_child(status_label)

	win_panel = ColorRect.new()
	win_panel.position = Vector2(320, 196)
	win_panel.size = Vector2(512, 236)
	win_panel.color = Color(0.05, 0.06, 0.10, 0.97)
	win_panel.visible = false
	canvas.add_child(win_panel)

	win_title = Label.new()
	win_title.position = Vector2(0, 34)
	win_title.size = Vector2(512, 44)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 34)
	win_title.add_theme_color_override("font_color", Color("#f4f7ff"))
	win_panel.add_child(win_title)

	win_subtitle = Label.new()
	win_subtitle.position = Vector2(24, 94)
	win_subtitle.size = Vector2(464, 110)
	win_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_subtitle.add_theme_font_size_override("font_size", 15)
	win_subtitle.add_theme_color_override("font_color", Color("#aeb9ca"))
	win_panel.add_child(win_subtitle)


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			switch_control()
		elif event.keycode == KEY_Q:
			swap_characters()
		elif event.keycode == KEY_R:
			reset_level()
		elif event.keycode == KEY_ENTER and game_won:
			reset_level()


func switch_control():
	if game_won:
		return

	if active_character == player:
		active_character = shadow
	else:
		active_character = player

	show_message("CONTROL: " + str(active_character.get("character_name")), 0.8)
	update_ui()


func swap_characters():
	if game_won:
		return

	var player_position = player.global_position
	var player_world = int(player.get("world_id"))

	player.global_position = shadow.global_position
	shadow.global_position = player_position

	player.set_world(int(shadow.get("world_id")))
	shadow.set_world(player_world)

	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	swap_count += 1
	last_swap_midpoint = (player.global_position + shadow.global_position) / 2.0
	swap_flash = 1.0

	show_message("WORLD SWAP", 0.9)
	queue_redraw()


func reset_level():
	if game_won:
		game_won = false
		win_panel.visible = false

	player.global_position = PLAYER_START
	shadow.global_position = SHADOW_START

	player.set_world(REAL_WORLD)
	shadow.set_world(SHADOW_WORLD)

	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	active_character = player
	reset_count += 1

	if reset_count > 1:
		show_message("RESET", 0.7)

	update_ui()
	queue_redraw()


func _on_goal_body_entered(body):
	if body != player or game_won:
		return

	game_won = true
	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	win_panel.visible = true
	win_title.text = "LEVEL CLEAR"
	win_subtitle.text = "You solved the first Shadow Swap puzzle.\n\nSwaps: " + str(swap_count) + "    Resets: " + str(reset_count) + "\n\nPress ENTER or R to restart."
	status_label.text = "GOAL REACHED"
	queue_redraw()


func show_message(text_value, duration):
	message_label.text = text_value
	message_time = duration


func update_ui():
	if player == null or shadow == null:
		return

	if active_character == shadow:
		active_label.text = "CONTROL: SHADOW"
		active_label.add_theme_color_override("font_color", Color("#b993ff"))
	else:
		active_label.text = "CONTROL: REAL"
		active_label.add_theme_color_override("font_color", Color("#55d6ff"))

	var world_name = "REAL WORLD"
	if int(active_character.get("world_id")) == SHADOW_WORLD:
		world_name = "SHADOW WORLD"

	status_label.text = "Move the shadow onto the upper route, then press Q to swap into its position.    " + world_name


func _process(delta):
	if swap_flash > 0.0:
		swap_flash = maxf(swap_flash - delta * 2.4, 0.0)

	if message_time > 0.0:
		message_time = maxf(message_time - delta, 0.0)
		if message_time <= 0.0:
			message_label.text = ""

	update_ui()
	queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#0b0e14"))

	draw_rect(Rect2(0, 108, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 108), Color(0.05, 0.09, 0.12, 0.45))
	draw_rect(Rect2(VIEW_SIZE.x / 2.0, 108, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 108), Color(0.10, 0.07, 0.14, 0.45))

	for x in range(0, int(VIEW_SIZE.x) + 1, 48):
		draw_line(Vector2(x, 108), Vector2(x, VIEW_SIZE.y), Color(1, 1, 1, 0.025), 1.0)

	for y in range(120, int(VIEW_SIZE.y) + 1, 48):
		draw_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y), Color(1, 1, 1, 0.025), 1.0)

	draw_line(Vector2(48, 126), Vector2(160, 126), Color("#55d6ff"), 3.0)
	draw_line(Vector2(992, 126), Vector2(1104, 126), Color("#b993ff"), 3.0)

	draw_circle(goal_position, 42.0, Color(0.33, 0.84, 1.0, 0.035))
	draw_arc(goal_position, 40.0, -PI / 2.0, PI * 1.5, 48, Color(0.33, 0.84, 1.0, 0.28), 2.0)

	if swap_flash > 0.0 and player != null and shadow != null:
		var radius = lerpf(28.0, 180.0, 1.0 - swap_flash)
		var alpha = swap_flash * 0.38
		draw_circle(last_swap_midpoint, radius, Color(0.55, 0.75, 1.0, alpha), false, 5.0)
		draw_line(player.global_position, shadow.global_position, Color(0.65, 0.78, 1.0, alpha), 2.0)

	draw_line(Vector2(40, 548), Vector2(1112, 548), Color(1, 1, 1, 0.05), 1.0)
