# ShadowSwap

ShadowSwap is a physics-based 2D stick-fighter arena prototype built around fast movement, jumping, close-range attacks, momentum and ring-outs.

The current build is deliberately focused on the core arena-fighter loop. The older detachable-body and Shadow Mode systems are not part of the active match.

The gameplay direction follows the broad characteristics published for Stick Fight: physics-based combat, stick figures, short arena matches, interactive platforms and procedural-looking character motion. The implementation uses original code and simple procedural graphics. citeturn281384search0

## Current match

- 2 local fighters
- fast horizontal movement
- jumping with variable height
- air control
- physical knockback
- melee attacks
- multiple platform layouts
- ring-out wins
- first to 5 rounds wins the match
- no weapon system in the current build
- AI temporarily disabled

## Controls

### Player 1

- **A / D** — move
- **W** or **Up Arrow** — jump
- **J** — punch
- **K** — kick

### Player 2

- **Left / Right** — move
- **Up Arrow** — jump
- **Comma (,)** — punch
- **Period (.)** — kick

- **R** — next round
- At match end, **R** starts a new match

## Fighter physics

Each fighter is a CharacterBody2D with:

- acceleration and deceleration
- gravity and momentum
- grounded and airborne movement
- coyote-time jump forgiveness
- variable jump height
- temporary hit stun
- strong knockback from attacks
- collision with the arena and other fighters

The character is rendered as a simple solid-color stick figure. Arms and legs use thick rounded pill-shaped strokes.

## Arena

The arena is made from simple solid platforms and rotates through several compact layouts between rounds.

A fighter who falls out of the arena loses the round.

## Project structure

- `main.tscn` — main scene
- `scripts/main.gd` — arena, match and scoring
- `scripts/fighter.gd` — fighter movement, animation and melee
- `scripts/arena_platform.gd` — platform collision and visuals

The project currently uses procedural graphics and no external art assets.
