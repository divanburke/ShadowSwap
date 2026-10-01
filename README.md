# ShadowSwap

ShadowSwap is a minimal 2D physics fighting game prototype with simple arcade movement and loose, physical stick-fighter body parts.

You control a stickman against an AI opponent. The core body is controlled directly for responsive movement, while the head, arms and legs stay physically connected and can detach during the fight.

## Controls

- **A / D** or **Left / Right** — move
- **Up Arrow** or **W** — jump
- **J** — punch
- **K** — kick
- **E** — Shadow Mode
- **R** — reset the fight

## Movement

The fighters use a responsive arcade controller rather than relying on raw forces for walking.

- running has acceleration and friction
- air control is weaker than ground control
- jumping is limited to grounded fighters
- losing one leg reduces movement speed
- losing both legs leaves only very limited movement

## Shadow Mode

Shadow Mode lasts for a few seconds and gives the fighter:

- complete temporary invulnerability
- stronger melee knockback
- stronger melee damage
- a visible purple state

Shadow Mode has a cooldown, so timing it matters.

## Body-part damage

The stickmen have:

- head
- torso
- left arm
- right arm
- left leg
- right leg

Body parts have their own health. When a part is lost, its physics joint is removed and the part becomes an independent physical object.

Losing an arm reduces available attacks. Losing a leg reduces movement. Losing the head or torso, or enough parts being detached, ends the round.

## AI

The AI:

- runs toward the player
- changes direction
- jumps
- punches and kicks
- sometimes backs away
- reacts to Shadow Mode
- uses Shadow Mode when available
- behaves with small random variations so fights do not play identically

## Arena

The arena uses a simple dark-grey style with slightly rounded platform corners. Platforms are placed at multiple heights so jumping and movement matter.

## Project structure

- `main.tscn` — main scene
- `scripts/main.gd` — arena, UI, rounds
- `scripts/fighter.gd` — player/AI movement, attacks, damage, Shadow Mode
- `scripts/limb.gd` — physical body-part visuals and physics
- `scripts/arena_platform.gd` — rounded physics platforms

The project uses Godot 4.7-compatible 2D physics nodes and joints and intentionally starts without external art or audio assets.
