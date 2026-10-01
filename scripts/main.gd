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

	var shadow_gate = create_door(Vector2(850, 430), Vector2(30, 180), Color("#b993ff"))
	var real_switch = create_switch(Vector2(180, 545), false, "REAL SWITCH")
	real_switch.connect_door(shadow_gate)

	# SHADOW side: pass the opened gate and hold the purple switch.
	create_platform("S1", Vector2(1000, 500), Vector2(150, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S2", Vector2(930, 410), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S3", Vector2(790, 330), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))
	create_platform("S4", Vector2(700, 260), Vector2(110, 20), SHADOW_WORLD, Color("#322848"), Color("#b993ff"))

	var real_gate = create_door(Vector2(410, 400), Vector2(30, 180), Color("#55d6ff"))
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

