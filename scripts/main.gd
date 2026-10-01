extends Node2D

const SwapCharacter = preload("res://scripts/character.gd")

const VIEW_SIZE := Vector2(1152.0, 648.0)
const PLAYER_START := Vector2(140.0, 535.0)
const SHADOW_START := Vector2(1012.0, 535.0)

const REAL_WORLD_MASK := 1
const SHADOW_WORLD_MASK := 2
const COMMON_WORLD_LAYER := 3
const PLAYER_LAYER := 4

var player: SwapCharacter
var shadow: SwapCharacter
var active_character: SwapCharacter

var goal_area: Area2D
var goal_position := Vector2(576.0, 118.0)

var status_label: Label
var active_label: Label
var message_label: Label
var win_panel: ColorRect
var win_title: Label
var win_subtitle: Label

var swap_flash := 0.0
var message_time := 0.0
var swap_count := 0
var death_count := 0
var game_won := false
var last_swap_midpoint := Vector2.ZERO

func _ready() -> void:
	build_level()
	build_characters()
	build_ui()

	active_character = player
	update_ui()
	queue_redraw()

func build_level() -> void:
	create_platform(
		"Ground",
		Vector2(576, 610),
		Vector2(1152, 76),
		COMMON_WORLD_LAYER,
		Color("#262b36"),
		Color("#3a4252")
	)

	# Real world: a staircase that stops before the central platform.
	create_platform(
		"RealStep1",
		Vector2(210, 500),
		Vector2(170, 22),
		REAL_WORLD_MASK,
		Color("#203c4b"),
		Color("#55d6ff")
	)

	create_platform(
		"RealStep2",
		Vector2(270, 415),
		Vector2(150, 22),
		REAL_WORLD_MASK,
		Color("#203c4b"),
		Color("#55d6ff")
	)

	create_platform(
		"RealStep3",
		Vector2(140, 320),
		Vector2(100, 22),
		REAL_WORLD_MASK,
		Color("#203c4b"),
		Color("#55d6ff")
	)

	# Shadow world: the final platform has a jump into the shared center.
	create_platform(
		"ShadowStep1",
		Vector2(942, 500),
		Vector2(170, 22),
		SHADOW_WORLD_MASK,
		Color("#332a48"),
		Color("#b993ff")
	)

	create_platform(
		"ShadowStep2",
		Vector2(882, 415),
		Vector2(150, 22),
		SHADOW_WORLD_MASK,
		Color("#332a48"),
		Color("#b993ff")
	)

	create_platform(
		"ShadowStep3",
		Vector2(900, 320),
		Vector2(160, 22),
		SHADOW_WORLD_MASK,
		Color("#332a48"),
		Color("#b993ff")
	)

	create_platform(
		"Center",
		Vector2(576, 245),
		Vector2(250, 24),
		COMMON_WORLD_LAYER,
		Color("#303744"),
		Color("#dce5f4")
	)

	create_platform(
		"GoalPlatform",
		Vector2(576, 145),
		Vector2(180, 22),
		COMMON_WORLD_LAYER,
		Color("#303744"),
		Color("#dce5f4")
	)

	create_goal()

func create_platform(
	platform_name: String,
	platform_position: Vector2,
	platform_size: Vector2,
	collision_layer_value: int,
	fill_color: Color,
	border_color: Color
) -> StaticBody2D:
	var platform := StaticBody2D.new()
	platform.name = platform_name
	platform.position = platform_position
	platform.collision_layer = collision_layer_value
	platform.collision_mask = 0
	add_child(platform)

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = platform_size
	collision.shape = rectangle
	platform.add_child(collision)

	var visual := Polygon2D.new()
	var half := platform_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	visual.color = fill_color
	platform.add_child(visual)

	var outline := Line2D.new()
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

	return platform

func build_characters() -> void:
	player = SwapCharacter.new()
	player.name = "Player"
	add_child(player)
	player.setup(
		self,
		false,
		PLAYER_START,
		1,
		Color("#f4f7ff"),
		Color("#55d6ff"),
		"REAL"
	)

	shadow = SwapCharacter.new()
	shadow.name = "Shadow"
	add_child(shadow)
	shadow.setup(
		self,
		true,
		SHADOW_START,
		2,
		Color("#d7c7ff"),
		Color("#b993ff"),
		"SHADOW"
	)

func create_goal() -> void:
	goal_area = Area2D.new()
	goal_area.name = "Goal"
	goal_area.position = goal_position
	goal_area.collision_layer = 16
	goal_area.collision_mask = PLAYER_LAYER
	add_child(goal_area)

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(100, 70)
	collision.shape = rectangle
	goal_area.add_child(collision)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-34, 30),
		Vector2(-34, -20),
		Vector2(34, -20),
		Vector2(34, 30)
	])
	visual.color = Color("#55d6ff")
	goal_area.add_child(visual)

	var glow := Polygon2D.new()
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

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2(28, 22)
	top_bar.size = Vector2(1096, 84)
	top_bar.color = Color(0.04, 0.05, 0.08, 0.82)
	canvas.add_child(top_bar)

	var title := Label.new()
	title.position = Vector2(48, 32)
	title.text = "SHADOW SWAP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(50, 69)
	subtitle.text = "BUILD 01  •  FIND A POSITION  •  SWAP WORLDS"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(subtitle)

	active_label = Label.new()
	active_label.position = Vector2(700, 34)
	active_label.size = Vector2(190, 24)
	active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	active_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(active_label)

	var controls := Label.new()
	controls.position = Vector2(900, 31)
	controls.size = Vector2(196, 52)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.text = "A / D or ← / →   MOVE\nSPACE   JUMP   •   TAB   CONTROL\nQ   SWAP   •   R   RESET"
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(controls)

	status_label = Label.new()
	status_label.position = Vector2(48, 570)
	status_label.size = Vector2(1056, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("#aeb9ca"))
	canvas.add_child(status_label)

	message_label = Label.new()
	message_label.position = Vector2(380, 116)
	message_label.size = Vector2(392, 38)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(message_label)

	win_panel = ColorRect.new()
	win_panel.position = Vector2(320, 196)
	win_panel.size = Vector2(512, 236)
	win_panel.color = Color(0.05, 0.06, 0.10, 0.96)
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
	win_subtitle.position = Vector2(28, 94)
	win_subtitle.size = Vector2(456, 100)
	win_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_subtitle.add_theme_font_size_override("font_size", 15)
	win_subtitle.add_theme_color_override("font_color", Color("#aeb9ca"))
	win_panel.add_child(win_subtitle)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			switch_control()
		elif event.keycode == KEY_Q:
			swap_characters()
		elif event.keycode == KEY_R:
			respawn_pair()
		elif event.keycode == KEY_ENTER and game_won:
			respawn_pair()

func switch_control() -> void:
	if game_won:
		return

	active_character = shadow if active_character == player else player
	show_message("CONTROL → " + active_character.character_name, 0.9)
	update_ui()

func swap_characters() -> void:
	if game_won:
		return

	var player_position := player.global_position
	var player_world := player.world_id

	player.global_position = shadow.global_position
	shadow.global_position = player_position

	player.set_world(shadow.world_id)
	shadow.set_world(player_world)

	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	swap_count += 1
	last_swap_midpoint = (player.global_position + shadow.global_position) * 0.5
	swap_flash = 1.0

	show_message("WORLD SWAP", 1.0)
	queue_redraw()

func respawn_pair() -> void:
	if game_won:
		game_won = false
		win_panel.visible = false

	player.global_position = PLAYER_START
	shadow.global_position = SHADOW_START

	player.set_world(1)
	shadow.set_world(2)

	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	active_character = player
	death_count += 1

	if death_count > 1:
		show_message("RESET", 0.7)

	update_ui()
	queue_redraw()

func _on_goal_body_entered(body: Node) -> void:
	if body != player or game_won:
		return

	game_won = true
	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	win_panel.visible = true
	win_title.text = "LEVEL CLEAR"
	win_subtitle.text = "You found the first solution.\n\nSwaps: %d   •   Resets: %d\n\nPress ENTER or R to play again." % [swap_count, death_count]
	status_label.text = "GOAL REACHED"
	queue_redraw()

func show_message(text_value: String, duration: float) -> void:
	message_label.text = text_value
	message_time = duration

func update_ui() -> void:
	if not player or not shadow or not active_label or not status_label:
		return

	var world_name := "REAL WORLD" if active_character.world_id == 1 else "SHADOW WORLD"
	var active_color := Color("#55d6ff") if active_character == player else Color("#b993ff")
	active_label.text = "CONTROL: " + active_character.character_name
	active_label.add_theme_color_override("font_color", active_color)

	status_label.text = (
		"Reach the center from the SHADOW side, then Q to swap into its position.  "
		+ "Current world: " + world_name
	)

func _process(delta: float) -> void:
	if swap_flash > 0.0:
		swap_flash = maxf(swap_flash - delta * 2.4, 0.0)

	if message_time > 0.0:
		message_time = maxf(message_time - delta, 0.0)
		if message_time <= 0.0:
			message_label.text = ""

	update_ui()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#0b0e14"))

	draw_rect(
		Rect2(0, 108, VIEW_SIZE.x * 0.5, VIEW_SIZE.y - 108),
		Color(0.05, 0.09, 0.12, 0.45)
	)

	draw_rect(
		Rect2(VIEW_SIZE.x * 0.5, 108, VIEW_SIZE.x * 0.5, VIEW_SIZE.y - 108),
		Color(0.10, 0.07, 0.14, 0.45)
	)

	for x in range(0, int(VIEW_SIZE.x) + 1, 48):
		draw_line(
			Vector2(x, 108),
			Vector2(x, VIEW_SIZE.y),
			Color(1, 1, 1, 0.025),
			1.0
		)

	for y in range(120, int(VIEW_SIZE.y) + 1, 48):
		draw_line(
			Vector2(0, y),
			Vector2(VIEW_SIZE.x, y),
			Color(1, 1, 1, 0.025),
			1.0
		)

	draw_line(Vector2(48, 126), Vector2(160, 126), Color("#55d6ff"), 3.0)
	draw_line(Vector2(992, 126), Vector2(1104, 126), Color("#b993ff"), 3.0)

	draw_circle(goal_position, 42.0, Color(0.33, 0.84, 1.0, 0.035))
	draw_circle(goal_position, 34.0, Color(0.33, 0.84, 1.0, 0.035))
	draw_arc(
		goal_position,
		40.0,
		-PI * 0.5,
		PI * 1.5,
		48,
		Color(0.33, 0.84, 1.0, 0.28),
		2.0
	)

	if swap_flash > 0.0 and player and shadow:
		var radius := lerp(28.0, 180.0, 1.0 - swap_flash)
		var alpha := swap_flash * 0.38

		draw_circle(
			last_swap_midpoint,
			radius,
			Color(0.55, 0.75, 1.0, alpha),
			false,
			5.0
		)

		draw_line(
			player.global_position,
			shadow.global_position,
			Color(0.65, 0.78, 1.0, alpha),
			2.0
		)

	draw_line(
		Vector2(40, 548),
		Vector2(1112, 548),
		Color(1, 1, 1, 0.05),
		1.0
	)
