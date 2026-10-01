# Shadow Swap

First playable Godot prototype for the Shadow Swap puzzle-platformer.

## Controls

- **A / D** or **Left / Right** — move
- **Space** — jump
- **Tab** — switch which character you control
- **Q** — swap the character and shadow positions/worlds
- **R** — reset the puzzle
- **Enter** — restart after clearing the level

## Prototype mechanic

The real character and shadow each have their own version of the level.

- Real-only platforms use the blue/cyan world.
- Shadow-only platforms use the purple world.
- Common platforms exist in both worlds.
- When you press **Q**, the player and shadow exchange positions **and their current world**, so the player can occupy the shadow's route.

## First puzzle

1. Start as the Real character.
2. Press **Tab** to control the Shadow.
3. Move the Shadow up the purple staircase.
4. Jump onto the central platform.
5. Press **Q** to swap into the Shadow's position.
6. Walk up to the glowing goal.

The level is intentionally simple so the core mechanic is easy to test before adding hazards, switches, doors, moving platforms, multiple shadows, and more complex puzzles.
