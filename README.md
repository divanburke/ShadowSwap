# ShadowSwap

ShadowSwap is a minimal 2D physics fighting game prototype inspired by simple stick-fighter arena games.

The player and AI use stable CharacterBody2D movement for reliable running and jumping. The visible stick-man body is procedurally animated, while knocked-off body parts become independent rigid bodies.

## Controls

- **A / D** or **Left / Right** — move
- **Up Arrow** or **W** — jump
- **J** — punch
- **K** — kick
- **E** — Shadow Mode
- **R** — reset the fight

## Character physics

The connected fighter uses a physics-aware character controller instead of trying to balance several rigid bodies at once.

- acceleration and deceleration create momentum
- gravity produces natural falling
- jump buffering and coyote time make jumping responsive
- releasing jump early produces a shorter jump
- air control is weaker than ground control
- incoming attacks add knockback and short stagger
- the character can collide with arena platforms and the other fighter
- the stick-man arms and legs animate with the character's movement

The controller is deliberately stable while the detached pieces use full rigid-body physics.

## Shadow Mode

Shadow Mode lasts for a few seconds and gives the fighter:

- temporary invulnerability
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

Each part has its own durability. When a part is lost, a separate rigid-body piece is spawned at its current location and inherits the fighter's momentum.

Losing one leg reduces movement and jump strength. Losing both arms removes punching. Losing the head or torso, or enough parts being detached, ends the round.

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
- `scripts/fighter.gd` — player/AI controller, movement, attacks, damage, Shadow Mode
- `scripts/limb.gd` — detached body-part visuals and physics
- `scripts/arena_platform.gd` — rounded physics platforms

The project uses Godot 4.7-compatible 2D physics and intentionally starts without external art or audio assets.
