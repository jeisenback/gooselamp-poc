# Section continuity

**Date:** 2026-10-13
**Status:** approved design, not yet planned
**Builds on:** `2026-10-12-metroidvania-slice-design.md`

## Why

The slice is thirteen rooms, each its own scene, loaded one at a time. A doorway is a wall with a gap in it until you step through, then a cut. The ring stopping is seen only in the room you stand in; the Hangar's gale is discovered after committing to it; the Locker's view of the Warden is a painting. The rooms do not read as one carrier.

This pass makes the section one place in three senses, decided in order:

1. **Spatial.** What you see leaving a room matches what you arrive at. Doorways are shared geometry, the camera looks a little way past a door, and crossing is a scroll, not a load.
2. **Place.** The Hulk reads as one carrier, to the depth the single scene makes cheap: a live porthole, a ring housing that turns, hull behind everything.
3. **State.** The two switches are legible wherever they matter: one hatch per door seen from both sides, the ring stopping seen in every room that gates on it, the gale seen before it is entered.

Not in this pass: per-room identity art, pacing, camera lookahead in the gale, enemy activation by distance, any change to the world graph's rooms, edges or required path.

## Decisions

- **One scene for the section.** Rooms stay separate scenes, instanced at their grid offsets. Chosen over a dead strip past each door, which serves only spatial continuity and doubles every doorway.
- **Camera limited to the current compartment, with lookahead past doors, scrolled.** Chosen over a free camera, which would show rooms through hull they were never composed to be seen through, and would give the Locker away.
- **Place cues limited to what the single scene makes cheap.** Four cues, listed below. Per-room identity waits for a pass where the scroll can be looked at.

## The section scene

`scenes/Section.tscn` is written by `tools/build_rooms.py`, after the rooms. It instances every room in `WorldGraph.ROOMS` as a child named after the room, at `grid.position * Vector2(1152, 648)`. Nothing else is in it but the backdrop (below). `Game` loads it once.

Rooms keep their own scenes, their `Room` script, their Compartment, Hull, Exits and contents. `Room.bounds()` already uses global positions, so it is correct at an offset. Compartments cover their own cells including their hull, never overlapping another room's cell. Adjacent rooms meet hull to hull: 32 px of each, 64 px in all.

### Doorways line up

Every edge in `WorldGraph.EDGES` names an exit on each side. In the section those two exits must sit at the same world position, so both rooms' hull openings form one doorway. Today four edges do not. The generator gains one rule: **the two exits of an edge share a world position, and the gravity room's floor-level door wins.** Applied:

| Edge | Change |
| --- | --- |
| Breach east, Dock west | Breach's east door moves down to the Dock's floor level. The Breach is zero-g; any height works. |
| Spine West east, Spine East west | Spine West's east door drops to Spine East's floor level, whose bottom is just above the gate's top. With the ring on, the gate's 200 px height is the lock: the floor is 200 px below the doorway and the jump reaches 96. With it off the gate floats clear. The return west is a drop over the gate's top in any state, as the slice design says. |
| Spine East east, Vent Room west | Spine East's floor is 220 px above the Vent Room's. The Vent Room gets three ledges at its west wall, each a jump apart, so the return west in gravity is three jumps. |
| Ring Deck east, Control Room west; Control Room east, Exit west | The Control Room becomes one cell tall, matching its map cell. The Warden's 280 px hover sits inside 584 px of interior. |

The other nine edges already line up and the section test (below) proves it stays so.

Doors as world-state objects stay as they are. Where a doorway has a door half in each room, both halves now sit at the same world spot and toggle on the same state; duplication is harmless and the generator may drop one half where it is exact.

### Exits

`Exit` nodes stay, with two jobs: the arrival point for `place()` and for tests, and the graph backstop. They no longer cause a load. The backstop stands: if a Player overlaps an Exit whose edge the graph forbids in the current state, Game sets the player back to the arrival point with zero velocity. The doors hold the player in practice; this guards a geometry leak.

### Backdrop

One polygon under the whole section in the hull colour, covering the union of the room cells grown by one lookahead. Where the camera looks past a door into a neighbour narrower than the room, it sees hull, not the clear colour.

## Camera

The current room is the compartment the player entered last, read from `player.tracker`. `Game` polls it each physics frame. When it changes, Game:

- sets the camera limits to the room's bounds, grown by `LOOKAHEAD` (384 px, one third of a screen) on each side that has an exit, hard at the hull on the others;
- records the visit in `WorldState`;
- tells the map.

The camera has position smoothing on and `limit_smoothed` on, so a limit change is a scroll, not a snap. Physics interpolation and the physics process callback stay as they are. `place()` still resets smoothing and interpolation, because it is a teleport.

## Game

`Game.enter(room, exit)` becomes `Game.place(room, exit)`: no load, no free, no cooldown. It sets the player at the exit's arrival point (or the checkpoint's spawn point when `exit` is empty), seeds the tracker with that room's compartment so gravity is right on the first frame, resets interpolation and applies the camera limits. Walking through a doorway is only walking. `SWAP_COOLDOWN` goes.

`Game.room` becomes `Game.current`, derived from the tracker. Respawn (`_checkpoint_for`), the map, launch options (`--room=`) and the title read it from there. The playtest and the tests do too.

Every spawner in the section is live from the start: about thirty enemies, which costs nothing measurable. Enemies behave whether or not the player is near; the Warden hovers in the Control Room from the first frame, which the porthole shows.

Shots are parented to Game as today and now carry through doorways.

## Place and state cues

1. **Locker porthole, live.** The painted miniature is replaced by a `SubViewport` that shares the main `World2D` and holds a `Camera2D` fixed on the Control Room's centre, drawn through a `SubViewportContainer` or a `Sprite2D` with the viewport texture on a 200 by 140 quad in the Locker's east wall, framed as today. The Warden seen is the one fought. Risk: the GL Compatibility renderer and the web build. The plan's first task on this cue is a probe in the web export; if it fails there, keep the painting and note it.
2. **Ring housing that turns.** The Ring Deck's arcs become a `RingHousing` node: a strip of arc segments that slides along the band while `WorldState.ring_on` and stops dead when it is off, by the same rule as `blister.gd`. The Control Room gets the same strip behind its panel. The ring stopping is then seen in the Blister, the Ring Deck and the Control Room.
3. **Section backdrop.** As above.
4. **Shared doorway objects.** Hatches, the Shaft's pressure door, the boss door and the Spine West gate are seen from both sides through the lookahead. No work beyond the section scene.

Free with the single scene, listed so nobody builds them: the Hangar's gale and streaks visible from the Workshop's door; the Vent Room's cabinet seen from the Locker's hatch; the Shaft's door seen from the Ring Deck.

## Testing

- **Game tests.** `enter` becomes `place`. The crossing test walks the player through a doorway and asserts the current room changes with a continuous position and kept velocity, no teleport. The gated-edge test starts the player on the floor below the doorway in gravity rooms and at the arrival point in zero-g ones, pushes outward for 0.6 s, and asserts the current room is unchanged and the player is inside its bounds. The camera test asserts limits equal bounds grown by the lookahead on exit sides only, and that a room change scrolls rather than snaps (the camera's position one frame after the change is still inside the old limits).
- **Section test**, new: every edge's two exits coincide in world space within 1 px; no two rooms' bounds overlap; each room's bounds equal its grid cells in world space; the Control Room is one cell; every room in the graph is a child of the section and vice versa.
- **Scenes match the graph, per-room, reachability, boundary** hold as they are: rooms are still scenes.
- **Pack check** also loads the section from the exported pack and runs the section test's coincidence check against it, because the export's resource conversion has dropped scene overrides before.
- **Playtest** reads the current room from the tracker. Its screenshots now show the lookahead and the scroll at doors.
- **Porthole** gets a probe before a test: a headless test asserts the viewport texture is non-empty after a frame; the web check is by eye on Pages.

## Starting values

| Value | Start |
| --- | --- |
| Lookahead past a door | 384 px |
| Camera position smoothing | 8.0 (Godot's `position_smoothing_speed`) |
| Porthole quad | 200 by 140 px |
| Porthole camera zoom | 0.35, framing the Control Room's width |
| Ring housing slide | 40 px/s while on |
| Vent Room ledges | 3, at 73 px steps, 80 px wide |
| Section backdrop | hull colour, cells grown by one lookahead |

## Open questions

- Whether the scroll at a door should ease or move at a fixed speed. Start with Godot's smoothing and judge in the playtest screenshots.
- Whether enemies should sleep when far from the player. Not until it costs something.
