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

## Tests

A Godot 4.5 binary named `godot` must be on the PATH.

```
godot --headless --import
godot --headless --fixed-fps 60 -s tests/run_tests.gd
```

Exit code 0 means every test passed. CI runs the same two commands on every pull request.
