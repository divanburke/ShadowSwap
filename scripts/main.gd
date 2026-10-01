extends Node2D

const CharacterScript = preload("res://scripts/character.gd")
const HazardScript = preload("res://scripts/hazard.gd")
const SwitchScript = preload("res://scripts/switch.gd")
const DoorScript = preload("res://scripts/door.gd")
const MovingPlatformScript = preload("res://scripts/moving_platform.gd")

const VIEW_SIZE = Vector2(1152, 648)

const REAL_WORLD = 1
const SHADOW_WORLD = 2
const COMMON_LAYER = 3

const LEVEL_COUNT = 3

var level_index = 0
var level_root
var player
var shadow
var active_character

var goal_area
var goal_position = Vector2.ZERO

var status_label
var active_label
var message_label
var level_label
var objective_label
var win_panel
var win_title
var win_subtitle

var swap_flash = 0.0
var message_time = 0.0
var swap_count = 0
var reset_count = 0
var game_won = false
var resetting = false
var last_swap_midpoint = Vector2.ZERO
var pulse_time = 0.0


func _ready():
	build_ui()
	start_level(0)


func start_level(new_level):
	level_index = clampi(new_level, 0, LEVEL_COUNT - 1)

	if level_root != null and is_instance_valid(level_root):
		level_root.free()

	level_root = Node2D.new()
	level_root.name = "Level_%02d" % (level_index + 1)
	add_child(level_root)
	move_child(level_root, 0)

	game_won = false
	resetting = false
	swap_flash = 0.0
	message_time = 0.0
	swap_count = 0

	build_current_level()
	active_character = player

	win_panel.visible = false
	update_level_ui()
	update_ui()

	show_message("LEVEL %02d" % (level_index + 1), 1.0)
	queue_redraw()


func build_current_level():
	if level_index == 0:
		build_level_01()
	elif level_index == 1:
		build_level_02()
	else:
		build_level_03()


func build_shared_ground():
	create_platform(
		"Ground",
		Vector2(576, 610),
		Vector2(1152, 76),
		COMMON_LAYER,
		Color("#232934"),
		Color("#40495a")
	)


func build_level_01():
	goal_position = Vector2(576, 118)

	build_shared_ground()

	create_world_marker(Vector2(110, 132), "REAL", Color("#55d6ff"))
	create_world_marker(Vector2(1042, 132), "SHADOW", Color("#b993ff"))

	create_platform("R1", Vector2(175, 510), Vector2(170, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R2", Vector2(250, 425), Vector2(150, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R3", Vector2(150, 335), Vector2(115, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))

	create_platform("S1", Vector2(975, 510), Vector2(170, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S2", Vector2(900, 425), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S3", Vector2(870, 335), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S4", Vector2(730, 285), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))

	create_platform("Center", Vector2(576, 245), Vector2(230, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))
	create_platform("Goal", Vector2(576, 145), Vector2(190, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))

	create_hazard(Vector2(576, 563), Vector2(420, 12), COMMON_LAYER, "THE VOID SPIKES")
	create_goal()
	build_characters_for_level()

	set_objective(
		"Reach the upper Shadow platform, then Q to swap into its position.",
		"1. TAB to control SHADOW\n2. Climb the purple route\n3. Reach the floating platform\n4. Q to swap\n5. Reach the cyan goal"
	)


func build_level_02():
	goal_position = Vector2(790, 126)

	build_shared_ground()

	create_world_marker(Vector2(110, 132), "REAL", Color("#55d6ff"))
	create_world_marker(Vector2(1042, 132), "SHADOW", Color("#b993ff"))

	# Real route.
	create_platform("R1", Vector2(175, 505), Vector2(180, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R2", Vector2(260, 420), Vector2(150, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R3", Vector2(345, 340), Vector2(150, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R4", Vector2(520, 340), Vector2(150, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R5", Vector2(665, 260), Vector2(180, 20), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))
	create_platform("R6", Vector2(790, 150), Vector2(180, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))

	# Shadow route to the switch.
	create_platform("S1", Vector2(975, 505), Vector2(170, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S2", Vector2(900, 420), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S3", Vector2(830, 330), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S4", Vector2(760, 265), Vector2(120, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))

	var door = create_door(Vector2(430, 420), Vector2(30, 180), Color("#55d6ff"))
	var switch = create_switch(Vector2(760, 230), true, "SHADOW SWITCH")
	switch.connect_door(door)

	create_hazard(Vector2(625, 560), Vector2(300, 12), REAL_WORLD, "REAL SPIKES")
	create_hazard(Vector2(995, 560), Vector2(90, 12), SHADOW_WORLD, "SHADOW SPIKES")

	create_goal()

	set_objective(
		"Park the Shadow on the purple switch to open the real door.",
		"1. TAB → SHADOW\n2. Reach the purple switch\n3. TAB → REAL\n4. Run through the open door\n5. Q when you need the final shortcut"
	)


func build_level_03():
	goal_position = Vector2(965, 108)

	# Deliberate pit: the final route must use the moving platform.
	create_platform("GroundLeft", Vector2(200, 610), Vector2(400, 76), COMMON_LAYER, Color("#232934"), Color("#40495a"))
	create_platform("GroundRight", Vector2(1026, 610), Vector2(252, 76), COMMON_LAYER, Color("#232934"), Color("#40495a"))

	create_world_marker(Vector2(110, 132), "REAL", Color("#55d6ff"))
	create_world_marker(Vector2(1042, 132), "SHADOW", Color("#b993ff"))

	# REAL side: hold the blue switch to open the Shadow gate.
	create_platform("R1", Vector2(180, 490), Vector2(180, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))
	create_platform("R2", Vector2(280, 400), Vector2(150, 20), REAL_WORLD, Color("#203c4b"), Color("#55d6ff"))

	var shadow_gate = create_door(Vector2(850, 425), Vector2(30, 300), Color("#b993ff"))
	var real_switch = create_switch(Vector2(180, 545), false, "REAL SWITCH")
	real_switch.connect_door(shadow_gate)

	# SHADOW side: pass the opened gate and hold the purple switch.
	create_platform("S1", Vector2(1000, 500), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S2", Vector2(930, 410), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S3", Vector2(790, 330), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S4", Vector2(700, 260), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))

	var real_gate = create_door(Vector2(410, 425), Vector2(30, 300), Color("#55d6ff"))
	var shadow_switch = create_switch(Vector2(700, 215), true, "SHADOW SWITCH")
	shadow_switch.connect_door(real_gate)

	# The only safe crossing over the pit is the moving platform.
	create_moving_platform(
		Vector2(500, 455),
		Vector2(650, 345),
		Vector2(135, 22),
		0.82,
		COMMON_LAYER,
		Color("#303744"),
		Color("#dce5f4")
	)

	# Escape platform is deliberately too high/far to be reached from the
	# moving platform in Real; the final Q swap puts the player beside it.
	create_platform("Escape", Vector2(840, 190), Vector2(150, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))
	create_platform("GoalPlatform", Vector2(965, 135), Vector2(170, 22), COMMON_LAYER, Color("#303744"), Color("#dce5f4"))

	create_hazard(Vector2(650, 590), Vector2(500, 70), COMMON_LAYER, "TIMING PIT")

	create_goal()

	build_characters_for_level()

	set_objective(
		"Chain both switches, cross the moving platform, then make the final swap.",
		"1. Stand REAL on blue switch   •   2. TAB → SHADOW   •   3. Cross the gate   •   4. Hold purple switch   •   5. TAB → REAL   •   6. Ride the platform   •   7. Q"
	)



func create_platform(platform_name, platform_position, platform_size, layer, fill_color, border_color):
	var platform = StaticBody2D.new()
	platform.name = platform_name
	platform.position = platform_position
	platform.collision_layer = layer
	platform.collision_mask = 0
	level_root.add_child(platform)

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


func create_hazard(hazard_position, hazard_size, world, hazard_name):
	var hazard = HazardScript.new()
	hazard.name = hazard_name.replace(" ", "_")
	hazard.position = hazard_position
	level_root.add_child(hazard)
	hazard.setup(self, world, hazard_name, hazard_size)


func create_switch(switch_position, shadow_only, display_name):
	var switch = SwitchScript.new()
	switch.name = display_name.replace(" ", "_")
	level_root.add_child(switch)
	switch.setup(self, switch_position, shadow_only, display_name)
	return switch


func create_door(door_position, door_size, door_color):
	var door = DoorScript.new()
	door.name = "Door_%d" % level_root.get_child_count()
	level_root.add_child(door)
	door.setup(door_position, door_size, door_color)
	return door


func create_moving_platform(start_position, end_position, platform_size, speed, layer, fill_color, border_color):
	var platform = MovingPlatformScript.new()
	platform.name = "MovingPlatform"
	level_root.add_child(platform)
	platform.setup(
		start_position,
		end_position,
		platform_size,
		speed,
		fill_color,
		border_color,
		layer
	)


func create_world_marker(marker_position, world_name, marker_color):
	var label = Label.new()
	label.position = marker_position
	label.text = world_name
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(marker_color, 0.75))
	level_root.add_child(label)


func build_characters_for_level():
	player = CharacterScript.new()
	player.name = "Player"
	level_root.add_child(player)

	shadow = CharacterScript.new()
	shadow.name = "Shadow"
	level_root.add_child(shadow)

	player.setup(
		self,
		false,
		Vector2(125, 530),
		REAL_WORLD,
		Color("#f4f7ff"),
		Color("#55d6ff"),
		"REAL"
	)

	shadow.setup(
		self,
		true,
		Vector2(1025, 530),
		SHADOW_WORLD,
		Color("#d7c7ff"),
		Color("#b993ff"),
		"SHADOW"
	)


func create_goal():
	goal_area = Area2D.new()
	goal_area.name = "Goal"
	goal_area.position = goal_position
	goal_area.collision_layer = 16
	goal_area.collision_mask = 4
	level_root.add_child(goal_area)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 75)
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


func set_objective(in_game_text, instruction_text):
	objective_label.text = in_game_text
	status_label.text = instruction_text.replace("\n", "    |    ")


func update_level_ui():
	level_label.text = "LEVEL %02d / %02d" % [level_index + 1, LEVEL_COUNT]

	if level_index == 0:
		objective_label.text = "CORE MECHANIC — POSITION THE SHADOW"
	elif level_index == 1:
		objective_label.text = "MECHANIC 02 — HOLD SWITCHES TO OPEN DOORS"
	else:
		objective_label.text = "MECHANIC 03 — CHAIN SWITCHES + MOVING PLATFORM"


func build_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var top_bar = ColorRect.new()
	top_bar.position = Vector2(24, 20)
	top_bar.size = Vector2(1104, 86)
	top_bar.color = Color(0.035, 0.045, 0.075, 0.94)
	canvas.add_child(top_bar)

	level_label = Label.new()
	level_label.position = Vector2(46, 28)
	level_label.text = "LEVEL 01 / 03"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(level_label)

	var title = Label.new()
	title.position = Vector2(45, 46)
	title.text = "SHADOW SWAP"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(title)

	active_label = Label.new()
	active_label.position = Vector2(620, 34)
	active_label.size = Vector2(190, 28)
	active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	active_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(active_label)

	var controls = Label.new()
	controls.position = Vector2(820, 31)
	controls.size = Vector2(275, 70)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.text = "A / D  or  ARROWS   MOVE\nUP ARROW   JUMP\nTAB   CONTROL SWITCH\nQ   SHADOW SWAP   |   R   RESET"
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(controls)

	objective_label = Label.new()
	objective_label.position = Vector2(250, 120)
	objective_label.size = Vector2(652, 30)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("#d8dfeb"))
	canvas.add_child(objective_label)

	message_label = Label.new()
	message_label.position = Vector2(390, 150)
	message_label.size = Vector2(372, 34)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 19)
	message_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(message_label)

	status_label = Label.new()
	status_label.position = Vector2(50, 574)
	status_label.size = Vector2(1052, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#8d99ad"))
	canvas.add_child(status_label)

	win_panel = ColorRect.new()
	win_panel.position = Vector2(308, 192)
	win_panel.size = Vector2(536, 258)
	win_panel.color = Color(0.04, 0.05, 0.08, 0.98)
	win_panel.visible = false
	canvas.add_child(win_panel)

	win_title = Label.new()
	win_title.position = Vector2(0, 32)
	win_title.size = Vector2(536, 48)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 34)
	win_title.add_theme_color_override("font_color", Color("#f4f7ff"))
	win_panel.add_child(win_title)

	win_subtitle = Label.new()
	win_subtitle.position = Vector2(30, 92)
	win_subtitle.size = Vector2(476, 135)
	win_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_subtitle.add_theme_font_size_override("font_size", 15)
	win_subtitle.add_theme_color_override("font_color", Color("#aeb9ca"))
	win_panel.add_child(win_subtitle)


func update_ui():
	if player == null or shadow == null or active_character == null:
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

	status_label.text = "Current world: " + world_name + "    |    Swaps: " + str(swap_count) + "    |    Resets: " + str(reset_count)


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			switch_control()
		elif event.keycode == KEY_Q:
			swap_characters()
		elif event.keycode == KEY_R:
			reset_level()
		elif event.keycode == KEY_ENTER and game_won:
			if level_index + 1 < LEVEL_COUNT:
				start_level(level_index + 1)
			else:
				start_level(0)


func switch_control():
	if game_won or resetting:
		return

	if active_character == player:
		active_character = shadow
	else:
		active_character = player

	show_message("CONTROL  →  " + str(active_character.get("character_name")), 0.75)
	update_ui()


func can_swap():
	return not game_won and not resetting and player != null and shadow != null


func swap_characters():
	if not can_swap():
		return

	var player_position = player.global_position
	var player_world = int(player.get("world_id"))
	var shadow_position = shadow.global_position
	var shadow_world = int(shadow.get("world_id"))

	player.global_position = shadow_position
	shadow.global_position = player_position

	player.set_world(shadow_world)
	shadow.set_world(player_world)

	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	swap_count += 1
	last_swap_midpoint = (player.global_position + shadow.global_position) / 2.0
	swap_flash = 1.0

	show_message("WORLD SWAP", 0.9)
	queue_redraw()


func reset_level():
	if resetting:
		return

	reset_count += 1
	start_level(level_index)


func player_hit(reason):
	if game_won or resetting:
		return

	resetting = true
	show_message(reason, 0.5)

	await get_tree().create_timer(0.25).timeout

	resetting = false
	reset_count += 1
	start_level(level_index)


func _on_goal_body_entered(body):
	if body != player or game_won or resetting:
		return

	game_won = true
	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	win_panel.visible = true

	if level_index + 1 < LEVEL_COUNT:
		win_title.text = "LEVEL %02d COMPLETE" % (level_index + 1)
		win_subtitle.text = "Swaps: %d    |    Resets: %d\n\nThe next mechanic is waiting.\n\nPress ENTER for Level %02d." % [
			swap_count,
			reset_count,
			level_index + 2
		]
	else:
		win_title.text = "SHADOW SWAP COMPLETE"
		win_subtitle.text = "You cleared all three prototype levels.\n\nSwaps: %d    |    Resets: %d\n\nPress ENTER to replay from Level 01." % [
			swap_count,
			reset_count
		]

	status_label.text = "GOAL REACHED  —  PRESS ENTER"
	queue_redraw()


func show_message(text_value, duration):
	message_label.text = text_value
	message_time = duration


func _process(delta):
	pulse_time += delta

	if swap_flash > 0.0:
		swap_flash = maxf(swap_flash - delta * 2.8, 0.0)

	if message_time > 0.0:
		message_time = maxf(message_time - delta, 0.0)
		if message_time <= 0.0:
			message_label.text = ""

	update_ui()
	queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#090c12"))

	draw_rect(
		Rect2(0, 108, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 108),
		Color(0.04, 0.09, 0.12, 0.56)
	)

	draw_rect(
		Rect2(VIEW_SIZE.x / 2.0, 108, VIEW_SIZE.x / 2.0, VIEW_SIZE.y - 108),
		Color(0.10, 0.065, 0.14, 0.56)
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

	var pulse = 1.0 + sin(pulse_time * 3.0) * 0.08

	if goal_area != null and is_instance_valid(goal_area):
		draw_circle(goal_position, 48.0 * pulse, Color(0.33, 0.84, 1.0, 0.035))
		draw_arc(
			goal_position,
			38.0 * pulse,
			-PI / 2.0,
			PI * 1.5,
			48,
			Color(0.33, 0.84, 1.0, 0.34),
			2.0
		)
		draw_arc(
			goal_position,
			31.0 * pulse,
			0.0,
			TAU,
			40,
			Color(0.33, 0.84, 1.0, 0.16),
			1.0
		)

	if swap_flash > 0.0 and player != null and shadow != null:
		var radius = lerpf(22.0, 220.0, 1.0 - swap_flash)
		var alpha = swap_flash * 0.42

		draw_circle(
			last_swap_midpoint,
			radius,
			Color(0.55, 0.75, 1.0, alpha),
			false,
			5.0
		)

		draw_circle(
			last_swap_midpoint,
			radius * 0.55,
			Color(0.75, 0.85, 1.0, alpha * 0.55),
			false,
			2.0
		)

		draw_line(
			player.global_position,
			shadow.global_position,
			Color(0.65, 0.78, 1.0, alpha),
			2.0
		)

	draw_line(
		Vector2(42, 552),
		Vector2(1110, 552),
		Color(1, 1, 1, 0.055),
		1.0
	)
