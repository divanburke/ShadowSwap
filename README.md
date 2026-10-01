# Shadow Swap

A small 2D puzzle-platformer prototype built with Godot 4.7.

The game is centered on one idea: you control a character and a shadow that exist in two versions of the level, and you can swap their positions and worlds.

## Controls

- **A / D** or **Left / Right** — move
- **Space** — jump
- **Tab** — switch control between Real and Shadow
- **Q** — swap positions and worlds
- **R** — reset the current level
- **Enter** — continue after a level is cleared

## Prototype progression

### Level 01 — The First Swap
Learn the basic mechanic. Move the Shadow up the purple route, position it beside the goal route, then press Q.

### Level 02 — Hold the Door
The Shadow can activate a purple-only switch. Leave the Shadow standing on it while you control the Real character through the opened door. The final position still matters.

### Level 03 — The Chain
Stand the Real character on the blue switch, switch to the Shadow, pass the opened gate, and hold the purple switch. Then return to the Real character, ride the moving platform across the pit, and make the final Q swap.

## Systems currently included

- Two simultaneous characters
- Separate Real and Shadow world collision layers
- Position + world swapping
- Character-specific switches
- Animated doors
- Moving platforms
- Spikes and a timing pit
- Level progression
- Reset and death flow
- Goal detection and level-complete screens
- Procedural visuals with no external art dependencies

The project intentionally starts with simple shapes and code-generated visuals. The next development stage can move these systems into reusable Godot scenes and add proper art, sound, particles, more puzzle mechanics, and a larger campaign.
