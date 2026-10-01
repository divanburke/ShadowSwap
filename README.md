# ShadowSwap

ShadowSwap is a minimal 2D physics fighting game prototype.

You control a stickman against an AI opponent. Every fighter is built from separate physical body parts connected with PinJoint2D constraints, so punches and kicks can knock individual parts loose.

## Controls

- **A / D** or **Left / Right** — move
- **Up Arrow** — jump
- **J** — punch
- **K** — kick
- **E** — Shadow Mode
- **R** — reset the fight

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

Losing one leg reduces movement and jump strength. Losing both legs leaves the fighter with only limited movement. Losing both arms removes punching. The head or torso being lost, or enough parts being detached, ends the round.

## AI

The AI:

- approaches the player
- changes direction
- jumps
- punches and kicks
- sometimes backs away
- reacts to Shadow Mode
- uses Shadow Mode when available
- behaves with small random variations so fights do not play identically

## Arena

The arena uses a simple dark-grey style with slightly rounded platform corners. The environment is deliberately restrained so the physical stickmen remain the focus.

## Current prototype structure

- `main.tscn` — main scene
- `scripts/main.gd` — arena, UI, rounds
- `scripts/fighter.gd` — player/AI control, attacks, damage, Shadow Mode
- `scripts/limb.gd` — physical body-part visuals and physics
- `scripts/arena_platform.gd` — rounded physics platforms

The project uses Godot 4.7-compatible 2D physics nodes and joints and intentionally starts without external art or audio assets.
