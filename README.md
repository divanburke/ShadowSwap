# ShadowSwap

ShadowSwap is currently a very small one-player stick-fighter prototype.

This build intentionally contains only the movement foundation:

- one player
- solid mint-green stickman
- connected head, torso, arms and legs
- rounded pill-shaped limbs
- slight walking animation
- forward/backward movement
- jumping
- directional arm hit

The direction of the last movement is stored, so pressing J makes the arm attack in that direction.

## Controls

- A / D or Left / Right — move
- W or Up Arrow — jump
- J — arm hit

## Current design

The fighter is a single CharacterBody2D with one capsule collision shape. The visible body is drawn as connected solid pill-shaped segments, so the player cannot collapse or separate while moving.

There is currently no:

- AI
- second player
- weapons
- detachable limbs
- damage system
- rounds
- scoring
- Shadow Mode

Those systems can be added later once the basic player movement and character feel are correct.

## Project structure

- main.tscn — main scene
- scripts/main.gd — creates the floor and one player
- scripts/fighter.gd — player movement, jump, animation and arm hit
