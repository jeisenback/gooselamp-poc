# Drift

A metroidvania vertical slice aboard the Hulk, a derelict carrier drifting in a graveyard of ships. The world changes because you changed it: progress is gated by world state the player flips, not by abilities the player gains. The switch is gravity. With the ring on, a compartment is a platformer; with it off, the same compartment is free movement in two dimensions with momentum that never decays. Every room is two games.

Design: `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md`. Milestones: `ROADMAP.md`.

## Controls

| Action | Keys | Joypad |
| --- | --- | --- |
| Move left | A, Left | left stick, d-pad left |
| Move right | D, Right | left stick, d-pad right |
| Move up | W, Up | left stick, d-pad up |
| Move down | S, Down | left stick, d-pad down |
| Jump (kick from a grab in zero-g) | Space, Z | A |
| Swing | X, J | X |
| Fire | C, K | B |
| Grab | Shift, L | right shoulder |
| Map | Tab, M | Y |

In gravity: run, a jump that is shorter when you release early, a four-way swing, a down swing in the air that pogos off enemies and hazards, and a crouch (hold down on the floor) whose swing goes low enough to hit what crawls at your feet. In zero-g: the movement keys thrust you (any angle on a stick) and you keep drifting when you let go; hold Grab against any surface to stop dead, aim and press Jump to kick off it faster than you can thrust; any swing that lands ricochets you away from the target. The gun has no recoil and fires the moment it is ready, even if you pressed early.

## Fighting

Swing is the main damage: three hits kill any enemy. Fire chips one health and staggers, interrupting what the target was doing. A hit on you costs one of five health, knocks you back and leaves you briefly invulnerable. Swing at an airlock to rest: full health, a save, and every enemy back. Dying returns you to the last airlock you rested at, with the world exactly as you left it.

- **Hull mite**: crawls along any surface in either state.
- **Drone**: faces you, winds up, charges in a straight line; level in gravity, across the whole room in zero-g. A shot cancels its charge.
- **Clinger**: a turret that spits a slow shot. Fixed in gravity; drifting debris in zero-g that the vents push and that keeps shooting.
- **The Warden**: the boss. With the ring on it hovers out of reach and repairs when left alone. With the ring off it charges and you can reach it. Throw the ring back on while it charges and it staggers down into reach.

## What the slice is

One section of the Hulk: a dock, a spine corridor, a breached wing, a vent branch, and the ring deck above. Thirteen rooms: Dock, Spine West, Breach, Blister, Spine East, Vent Room, Locker, Workshop, Hangar, Shaft, Ring Deck, Control Room, Exit. Start state: ring on, vents closed.

Two switches. The gravity ring is thrown from two panels, one in the Control Room and one in the Blister; off, the whole section is zero-g. The bulkhead vents are thrown from one panel in the Vent Room; open, wind runs east through the branch, the Hangar hatch opens, the Locker hatch shuts, and the Shaft's pressure door opens. The Breach and the Blister have dead plates: always zero-g. Airlocks are in the Dock and on the Ring Deck. The boss door opens for good when the Warden is down; the slice ends beyond it.

The section is one scene. Doorways are shared hull: both rooms open at the same place, and crossing one is a scroll, not a load. The camera is held to the room you are in, plus a third of a screen past each door, so a neighbour shows through its doorway and nowhere else. The Locker's window is a second camera on the Control Room: the Warden in the glass is the one you will fight. The ring's housing along the Ring Deck and the Control Room slides while the ring turns and stops when it is thrown off.

Launch options for testing, as `godot -- --room=Spine%20West --ring=off --vents=open` or `?room=Spine%20West&ring=off&vents=open` on the web: start in a room, preset the switches.

## Tests

A Godot 4.5 binary named `godot` must be on the PATH.

```
godot --headless --import
godot --headless --fixed-fps 60 -s tests/run_tests.gd
```

Exit code 0 means every test passed. The playtest plays scripted scenarios in the real game under a virtual display and saves a screenshot per step to `playtest_out/`:

```
xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd
```

CI runs both on every pull request and attaches the screenshots. `tools/build_rooms.py` writes the room scenes in `scenes/rooms/`; edit it and rerun it, or edit the scenes in the editor. `Section` places them at their `WorldGraph` grid offsets at runtime; a test checks that both sides of every doorway meet.

## Web build

`.github/workflows/web.yml` exports the Web preset and publishes it to GitHub Pages on every push to `main` (one-time setup: repository Settings, Pages, Source "GitHub Actions"). Locally, with the Web export template installed:

```
godot --headless --import
godot --headless --export-release "Web" build/web/index.html
```
