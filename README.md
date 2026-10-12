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

## Try it

Run the project (`godot` in this directory, or press play in the editor). The main scene is a test room: a box 2400 px wide with a bright seam down the middle. Left of the seam the plates are live and there is a floor; right of the seam the plates are dead and the compartment is zero-g, tinted cool, with a pillar in the middle.

- Walk right across the seam at speed and keep going straight: momentum crosses intact, nothing falls.
- Hold Grab (Shift) and drift into the pillar: you stop dead. Aim with the move keys and press Jump (Space) to kick off it.
- Fire (C) in zero-g to push yourself the other way; the gun is the only thruster.
- Swing (X) at the panel on the left wall at floor height to stop the ring: the left compartment turns cool and everything in it is zero-g. Swing it again to restart the ring.
- Swing at the panel on the pillar to open the vents: the right compartment becomes a wind blowing right, and you drift toward the far wall unless you grab something.
