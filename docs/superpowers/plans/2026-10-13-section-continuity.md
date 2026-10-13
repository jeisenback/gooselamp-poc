# Section Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The thirteen rooms become one scene with shared doorways, a camera that looks past doors and scrolls between rooms, and three cues that make the ring, the Warden and the hull read as one place.

**Architecture:** A `Section` node builds itself from `WorldGraph.ROOMS` at ready, instancing each room scene at its grid offset under a hull-coloured backdrop. `Game` loads it once; the current room is the compartment the player entered last, and it drives camera limits (room bounds grown by a lookahead on exit sides), visits and the map. The room generator realigns four doorways so both sides of every edge open at the same world coordinate. A `RingHousing` node and a `Porthole` scene are the place cues.

**Tech Stack:** Godot 4.5 stable, GDScript, GL Compatibility; headless test runner `tests/run_tests.gd`; playtest under xvfb; `tools/build_rooms.py` for rooms.

**Spec:** `docs/superpowers/specs/2026-10-13-section-continuity-design.md`

## Global Constraints

- Cell is 1152 by 648; hull thickness `T = 32`; doors stand `DOOR = 24` proud of the hull.
- Lookahead past a door: 384 px. Camera `position_smoothing_speed` 8.0.
- Porthole quad 200 by 140, its camera zoom 0.35, fixed on the Control Room's centre.
- Ring housing slides 40 px/s while the ring is on, stops dead when off.
- Vent Room steps: three, 73 px rises, 80 px wide.
- Rooms stay separate scenes under `scenes/rooms/`, written by `tools/build_rooms.py`; rerun it after every generator change and commit the scenes with it.
- `WorldGraph` is the one source of the grid, the edges and the required path; nothing in this plan duplicates them.
- Run the suite with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (set `TEST_FILTER=<substring>` to narrow it); the playtest with `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`.
- Commits end with the session's attribution trailers. No model names in any file.

## Review Focus

1. A player who dies with a foot in a doorway, overlapping two compartments: the current room must not change while dead, and the respawn must seed the airlock's compartment, so the first frame after respawn has the right gravity. Test in Task 3.
2. Respawn while the camera is mid-scroll, or across the section: the camera must appear at the airlock on the next frame, never scroll the length of the Hulk. Test in Task 4.
3. A zero-g player stopped exactly in the 64 px of hull between two rooms: both rooms' bounds contain them, so the tracker is never empty and gravity never flips to space. Test in Task 1.
4. `?room=Locker` on the web, a room without an airlock: `place` falls back to the first exit's arrival point and the camera limits are the Locker's. Test in Task 3.
5. The Spine West gate with the ring on: the floor below the realigned doorway is 200 px down and the jump reaches 96, so the only way through is the gate's top, which cannot be reached. The gated-edge test must start on the floor, not at the arrival point above the gate, or it passes for the wrong reason. Test in Task 3.

---

### Task 1: The Section

**Files:**
- Create: `scripts/section.gd`
- Create: `tests/test_section.gd`

**Interfaces:**
- Consumes: `WorldGraph.ROOMS` (grid per room), `Game.scene_path(name)`, `Room.bounds()`, `Room.exits()`.
- Produces: `class_name Section extends Node2D` with `const CELL := Vector2(1152, 648)`, `const LOOKAHEAD := 384.0`, `func room(room_name: String) -> Room` (null when absent; node name is the room name without spaces, as `Game.scene_path` spells it), `func rooms() -> Array[Room]`, and a first child `Backdrop: Polygon2D`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _section() -> Section:
	return add(Section.new()) as Section

func test_every_room_is_a_child_at_its_grid_offset() -> void:
	var s := _section()
	for name in WorldGraph.ROOMS:
		var r := s.room(name)
		assert_true(r != null, "%s is in the section" % name)
		if r == null:
			continue
		var want := Vector2(WorldGraph.ROOMS[name].grid.position) * Section.CELL
		assert_true(r.global_position.is_equal_approx(want), "%s at %s, want %s" % [name, r.global_position, want])
	assert_eq(s.rooms().size(), WorldGraph.ROOMS.size(), "all of them, nothing else")

func test_rooms_touch_but_never_overlap() -> void:
	var s := _section()
	var rooms := s.rooms()
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a := rooms[i].bounds()
			var b := rooms[j].bounds()
			assert_true(not a.intersects(b, false), "%s and %s overlap" % [rooms[i].room_name, rooms[j].room_name])

func test_the_hull_between_two_rooms_belongs_to_both() -> void:
	var s := _section()
	var dock := s.room("Dock")
	var spine := s.room("Spine West")
	var seam := Vector2(dock.bounds().end.x, dock.exit_named("east").global_position.y)
	assert_true(dock.bounds().has_point(seam - Vector2(1, 0)) and spine.bounds().has_point(seam + Vector2(1, 0)), "no gap at the seam")
	assert_true(dock.bounds().has_point(dock.exit_named("east").global_position), "the exit's hull is inside the room")

func test_backdrop_covers_every_room_and_the_lookahead() -> void:
	var s := _section()
	var back := s.get_node("Backdrop") as Polygon2D
	assert_true(back != null and s.get_child(0) == back, "first child, drawn under the rooms")
	var all := Rect2()
	for r in s.rooms():
		all = r.bounds() if all.size == Vector2.ZERO else all.merge(r.bounds())
	var want := all.grow(Section.LOOKAHEAD)
	var got := Rect2(back.polygon[0], back.polygon[2] - back.polygon[0])
	assert_true(got.encloses(want), "backdrop %s encloses %s" % [got, want])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=test_section godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: fails to parse, `Section` not declared.

- [ ] **Step 3: Implement `scripts/section.gd`**

`_ready()` instances `load(Game.scene_path(name))` for every room in `WorldGraph.ROOMS`, names it `name.replace(" ", "")`, positions it at `grid.position * CELL`, and adds it. Before the rooms, it adds `Backdrop`: a `Polygon2D` in the generator's hull colour `Color(0.1, 0.11, 0.13)` whose four points are the union of the grid cells (in world px) grown by `LOOKAHEAD`, clockwise from the top left. `room()` is `get_node_or_null`; `rooms()` collects children that are `Room`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `TEST_FILTER=test_section godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/section.gd scripts/section.gd.uid tests/test_section.gd
git commit -m "Section: the thirteen rooms in one scene, at their grid offsets, over a hull backdrop"
```

### Task 2: Doorways line up

**Files:**
- Modify: `tools/build_rooms.py` (`breach`, `spine_west`, `vent_room`, `control_room`, `Room.write` wall naming)
- Modify: `tests/test_section.gd` (add), `tests/test_rooms_top.gd:30-38`, `tests/test_rooms_branch.gd` (add)
- Regenerate: `scenes/rooms/*.tscn`

**Interfaces:**
- Consumes: `Section` from Task 1, `Exit.inward`, `Exit.global_position`.
- Produces: every edge's two exits share a hull seam point; Control Room one cell; Vent Room hull blocks named `Step0`, `Step1`, `Step2` under `Hull`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_section.gd`:

```gdscript
## The seam point of an exit: the hull's outer face at the doorway's centre.
func _seam(e: Exit) -> Vector2:
	return e.global_position - e.inward * 16.0

func test_every_edge_s_two_exits_meet_at_the_same_seam() -> void:
	var s := _section()
	for e in WorldGraph.EDGES:
		var a := s.room(e[0]).exit_named(e[1])
		var b := s.room(e[2]).exit_named(e[3])
		assert_true(_seam(a).distance_to(_seam(b)) <= 1.0, "%s %s meets %s %s: %s vs %s" % [e[0], e[1], e[2], e[3], _seam(a), _seam(b)])
		assert_true(a.inward.is_equal_approx(-b.inward), "%s %s faces %s %s" % [e[0], e[1], e[2], e[3]])
```

In `tests/test_rooms_top.gd`, replace the hover-height assertion in `test_control_room_holds_panel_one_the_warden_and_the_door` with:

```gdscript
	assert_true(r.bounds().size.is_equal_approx(Vector2(1152, 648)), "one cell, as on the map")
	var warden := r.find_children("*", "Spawner", true, false)[0]
	assert_true(warden.position.y <= r.floor_y - Warden.HOVER_HEIGHT and warden.position.y >= Warden.HALF_SIZE + 32.0, "the hover fits")
```

In `tests/test_rooms_branch.gd`:

```gdscript
func test_vent_room_steps_climb_to_spine_east_s_door() -> void:
	var r := _room("VentRoom")
	var door_bottom := r.exit_named("west").global_position.y + 68.0
	var last_top := r.floor_y
	for i in range(3):
		var step := r.get_node("Hull/Step%d" % i) as CollisionShape2D
		var top := step.position.y - step.shape.size.y / 2.0
		assert_true(last_top - top >= 60.0 and last_top - top <= 80.0, "step %d rises %f" % [i, last_top - top])
		assert_true(step.shape.size.x >= 80.0, "step %d is wide enough to land on" % i)
		last_top = top
	assert_true(absf(last_top - door_bottom) <= 8.0, "the top step is the door's sill")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=test_ godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: the seam test names four edges (Breach east, Spine West east, Spine East east, Ring Deck east or Control Room east); the Control Room and step tests fail.

- [ ] **Step 3: Change the generator**

- `Room.write`: name a hull wall after its block's name when one was given, else `Wall%d`; keep the art name `WallArt%d`.
- `breach()`: the east exit at the default height (drop the `324`).
- `spine_west()`: `r.exit("east", "right", 328)` with a comment that 328 is Spine East's floor-level door, so the doorway's bottom at 396 sits above the gate's top at 416, and the floor is 220 px below it.
- `vent_room()`: `r.exit("west", "left", 328)`; three blocks `r.block(32, 543, 80, 24, color=SCENERY, name="Step0")`, `r.block(150, 470, 80, 24, color=SCENERY, name="Step1")`, `r.block(32, 397, 80, 24, color=SCENERY, name="Step2")`: a zigzag so no step is directly under another within a body height, clear of the cabinet at x 220 to 380.
- `control_room()`: cells `(1, 1)`; the Warden spawner at `(576, fy - 280)` as now; delete the two-cells comment.

Then `python3 tools/build_rooms.py`.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: all pass. If the existing Game gated-edge test now fails on Spine West east with the ring on, that is Review Focus 5 and Task 3 rewrites it; note it and go on.

- [ ] **Step 5: Commit**

```bash
git add tools/build_rooms.py scenes/rooms tests/test_section.gd tests/test_rooms_top.gd tests/test_rooms_branch.gd
git commit -m "Rooms: both sides of every doorway open at the same world coordinate"
```

### Task 3: Game on the section

**Files:**
- Modify: `scripts/game.gd` (whole file), `scripts/map.gd:81-88`
- Modify: `tests/test_game.gd` (whole file)

**Interfaces:**
- Consumes: `Section` (Task 1), `Player.tracker: CompartmentTracker`, `Player.enter_compartment`, `Player.respawn`, `Respawner.bind(player, lookup)`, `WorldGraph.edge`, `WorldGraph.allows`.
- Produces: `Game.section: Section`, `Game.current: Room` (null until the player is placed), `func place(room_name: String, exit_name: String) -> void`, `func has_room(room_name: String) -> bool` (instance method now), `static func scene_path` unchanged. `Game.enter`, `Game.room` and `SWAP_COOLDOWN` are gone. `_apply_limits(r: Room)` exists as a stub that sets limits to the bounds; Task 4 finishes it.

- [ ] **Step 1: Rewrite `tests/test_game.gd`**

Keep `_game()`, the boss-container test and the save-fallback test (with `g.current.room_name`). Replace the rest:

```gdscript
func test_starts_in_the_dock_with_nothing_saved() -> void:
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.current.room_name, "Dock", "the Dock")
	assert_true(Array(WorldState.visited).has("Dock"), "visited")
	assert_true(g.player.global_position.distance_to(g.current.checkpoint().spawn_point()) < 2.0, "at the airlock")

func test_walking_through_a_doorway_changes_the_room_without_a_teleport() -> void:
	var g := _game()
	g.place("Dock", "west")
	await physics_frames(2)
	g.player.velocity = Vector2(-150, 0)
	g.player.input_override.aim = Vector2.LEFT
	var last := g.player.global_position
	var biggest := 0.0
	for i in range(frame_count(0.5)):
		await physics_frames(1)
		biggest = maxf(biggest, g.player.global_position.distance_to(last))
		last = g.player.global_position
	assert_eq(g.current.room_name, "Breach", "now the Breach")
	assert_true(biggest < 10.0, "no frame jumped the player, biggest step %f" % biggest)
	assert_true(g.player.velocity.x < -100.0, "still moving left")
	assert_true(g.player.in_zero_g(), "the Breach is zero-g")
	assert_true(Array(WorldState.visited).has("Breach"), "visited on entry")

func test_the_backstop_refuses_a_crossing_the_graph_forbids() -> void:
	var g := _game()
	g.place("Spine West", "")
	await physics_frames(2)
	var east := g.current.exit_named("east")
	g.player.global_position = east.global_position
	g.player.velocity = Vector2(300, 0)
	await physics_frames(2)
	assert_eq(g.current.room_name, "Spine West", "held")
	assert_true(absf(g.player.global_position.x - east.arrival_point().x) < 2.0 and g.player.velocity.x == 0.0, "set back at the arrival point, stopped (gravity may have begun to act since)")

func test_death_before_resting_returns_to_the_dock_airlock() -> void:
	var g := _game()
	g.place("Breach", "west")
	await physics_frames(2)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	assert_eq(g.current.room_name, "Dock", "back at the Dock")
	assert_true(not g.player.dead and not g.player.in_zero_g(), "alive, in gravity from the first frame")

func test_a_dead_body_drifting_through_a_doorway_does_not_change_the_room() -> void:
	var g := _game()
	g.place("Breach", "east")
	await physics_frames(2)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	g.player.velocity = Vector2(200, 0)
	await physics_frames(frame_count(0.5))
	assert_eq(g.current.room_name, "Breach", "the dead drift, the room does not follow")

func test_a_room_without_an_airlock_places_at_its_first_exit() -> void:
	var g := _game()
	g.place("Locker", "")
	await physics_frames(2)
	assert_eq(g.current.room_name, "Locker", "the Locker")
	assert_true(g.player.global_position.distance_to(g.current.exits()[0].arrival_point()) < 2.0, "at the hatch")

func test_entering_a_room_seeds_the_compartment_before_physics_runs() -> void:
	var g := _game()
	g.place("Dock", "")
	assert_eq(g.player.tracker.compartments.size(), 1, "inside the Dock's compartment at once")
	assert_true(not g.player.in_zero_g(), "gravity from the first frame")
	assert_eq(g.current.room_name, "Dock", "current at once")

## Every gated edge is shut by geometry when its needs fail. In gravity the
## player starts on the floor below the doorway (the Spine West gate's top is
## the lock, and starting above it would pass for the wrong reason); in zero-g
## at the arrival point.
func test_every_gated_edge_is_shut_when_its_needs_fail() -> void:
	var g := _game()
	var states := []
	for ring_on in [true, false]:
		for vents_open in [false, true]:
			for boss_down in [false, true]:
				states.append({"ring_on": ring_on, "vents_open": vents_open, "boss_down": boss_down})
	for e in WorldGraph.EDGES:
		if e[4].is_empty():
			continue
		for state in states:
			if WorldGraph.allows(e[4], state):
				continue
			WorldState.reset()
			WorldState.set_ring(state.ring_on)
			WorldState.set_vents(state.vents_open)
			if state.boss_down:
				WorldState.set_boss_down()
			g.place(e[0], e[1])
			await physics_frames(2)
			var room := g.current
			var exit := room.exit_named(e[1])
			var inward: Vector2 = exit.inward
			if not g.player.in_zero_g() and inward.y == 0.0:
				g.player.global_position = Vector2(exit.arrival_point().x, room.global_position.y + room.floor_y - 24.0)
			g.player.velocity = -inward * 220.0
			g.player.input_override.aim = -inward
			g.player.input_override.grab_held = false
			for i in range(frame_count(0.6)):
				await physics_frames(1)
				if g.player.in_zero_g():
					g.player.velocity = -inward * 220.0
			var label := "%s %s with ring_on=%s vents_open=%s boss_down=%s" % [e[0], e[1], state.ring_on, state.vents_open, state.boss_down]
			assert_eq(g.current.room_name, e[0], "%s: stays in the room" % label)
			assert_true(room.bounds().grow(-40.0).has_point(g.player.global_position), "%s: held well inside, at %s" % [label, g.player.global_position])
			g.player.input_override.aim = Vector2.ZERO
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=test_game godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: fails to parse, `place` and `current` not found.

- [ ] **Step 3: Rewrite `scripts/game.gd`**

- `_ready()`: as now, then `section = Section.new()`, `add_child(section)`, `move_child(section, 0)`; for every room and every exit, `e.crossed.connect(_on_exit_crossed.bind(r))`.
- `_physics_process(delta)`: camera follows the player; then `_sync_current()`.
- `_sync_current()`: the last compartment in `player.tracker.compartments`, its parent as `Room`; if `player.dead` return; if it differs from `current`: set it, `_apply_limits(current)`, `WorldState.visit`, `$Map.set_current`.
- `place(room_name, exit_name)`: fall back to `WorldGraph.START` when `not has_room`; position as `enter` did (exit arrival, else checkpoint spawn, else first exit, else bounds centre); keep velocity; `grabbed = false`; clear the tracker and `enter_compartment(r.compartment)`; `current = null` then `_sync_current()` so limits, visit and map apply at once; `camera.global_position = player.global_position`, `camera.reset_smoothing()`, both `reset_physics_interpolation()`.
- `_apply_limits(r: Room)`: for now sets the four limits to `r.bounds()`.
- `_on_exit_crossed(exit: Exit, room: Room)`: return if `player.dead`; look up the edge; if the graph forbids it in the current state, set the player to `exit.arrival_point()` with zero velocity.
- `start()`: as now with `place`; the `--room=` branch keeps its first-exit fallback through `place`.
- `_checkpoint_for(room_name)`: the section's room (or the Dock's); clear the tracker and seed that room's compartment; return its checkpoint.
- `has_room(name)`: `section.room(name) != null`.

In `scripts/map.gd`, `game.room` becomes `game.current` in `_draw_map`.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: all pass, including the gated-edge test over every state.

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd scripts/map.gd tests/test_game.gd
git commit -m "Game: one section, placed into rather than loaded; the current room follows the player"
```

### Task 4: Camera limits with lookahead, scrolled

**Files:**
- Modify: `scripts/game.gd` (`_apply_limits`), `scenes/Main.tscn` (Camera2D)
- Modify: `tests/test_game.gd` (add)

**Interfaces:**
- Consumes: `Section.LOOKAHEAD`, `Room.exits()`, `Exit.inward`.
- Produces: camera limits per room: bounds grown by `LOOKAHEAD` on each side with an exit (`inward.x > 0` grows the left, `< 0` the right, `inward.y > 0` the top, `< 0` the bottom).

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_camera_limits_look_past_doors_only() -> void:
	var g := _game()
	g.place("Dock", "")
	var b := g.current.bounds()
	var cam := g.get_node("Camera2D") as Camera2D
	assert_eq(cam.limit_left, int(b.position.x - Section.LOOKAHEAD), "west door")
	assert_eq(cam.limit_right, int(b.end.x + Section.LOOKAHEAD), "east door")
	assert_eq(cam.limit_top, int(b.position.y), "no door above")
	assert_eq(cam.limit_bottom, int(b.end.y), "no door below")

func test_a_room_change_scrolls_the_camera() -> void:
	var g := _game()
	g.place("Dock", "west")
	await physics_frames(2)
	var cam := g.get_node("Camera2D") as Camera2D
	g.player.velocity = Vector2(-150, 0)
	g.player.input_override.aim = Vector2.LEFT
	while g.current.room_name == "Dock":
		await physics_frames(1)
	var breach := g.current.bounds()
	await physics_frames(1)
	assert_true(cam.get_screen_center_position().x > breach.end.x + Section.LOOKAHEAD - 576.0, "one frame in, still looking from the Dock's side")
	await physics_frames(frame_count(2.0))
	assert_true(cam.get_screen_center_position().x <= breach.end.x + Section.LOOKAHEAD - 576.0 + 1.0, "two seconds in, inside the Breach's limits")

func test_respawn_does_not_scroll_across_the_section() -> void:
	var g := _game()
	g.place("Ring Deck", "east")
	await physics_frames(2)
	g.current.checkpoint().rest(g.player)
	g.place("Hangar", "west")
	await physics_frames(2)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	var cam := g.get_node("Camera2D") as Camera2D
	assert_eq(g.current.room_name, "Ring Deck", "back at the airlock")
	assert_true(g.current.bounds().grow(Section.LOOKAHEAD).has_point(cam.get_screen_center_position()), "the camera is there too, at once")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=camera godot --headless --fixed-fps 60 -s tests/run_tests.gd` and `TEST_FILTER=scroll` likewise.
Expected: the limits test fails on `limit_left`; the scroll test fails on "one frame in".

- [ ] **Step 3: Implement**

`_apply_limits` grows the bounds per exit side as the Interfaces block says. A respawn is a teleport the Game does not perform itself: `_checkpoint_for` raises a flag, and on the next `_physics_process`, after following the player, Game resets the camera's smoothing and physics interpolation and clears it (the Respawner moves the player later in the same frame, so the next frame sees the new position). In `scenes/Main.tscn` the Camera2D gets `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`, `limit_smoothed = true`, keeping `process_callback = 0` and the drag margins. If the scroll test's first assertion still fails because Godot clamps to new limits at once, Game eases the limits itself: `_apply_limits` records targets and `_physics_process` moves each limit toward its target by at most 1200 px per second; `place` applies targets at once.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd scenes/Main.tscn tests/test_game.gd
git commit -m "Camera: limited to the room plus a third of a screen past each door, scrolled between rooms"
```

### Task 5: Playtest and pack check on the section

**Files:**
- Modify: `tests/playtest.gd`, `tests/check_pack.gd`

**Interfaces:**
- Consumes: `Game.place`, `Game.current`, `Section`.

- [ ] **Step 1: Update the playtest**

`game.enter` becomes `game.place`, `game.room` becomes `game.current` throughout. In `_required_path`, after the Workshop's own screenshot and before the Hangar edge, add `game.place("Workshop", "east")`, `await frames(30)`, `await shot("Workshop east door, Hangar beyond")`. In `_end_game`, also free a `Section` child of root if one is left.

- [ ] **Step 2: Run the playtest**

Run: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`
Expected: `3 scenarios, 0 failed`. Open `playtest_out/required_path_*_Workshop_east_door*.png` and confirm the Hangar's hatch and ledge are in frame to the right of the Workshop's wall.

- [ ] **Step 3: Extend the pack check**

After the per-room loop, add a `Section.new()` to root, run the seam check from Task 2 over every edge (same 1 px tolerance), print one line per failing edge and `section ok` otherwise, and count failures into the exit code.

- [ ] **Step 4: Export and check the pack**

Run: `godot --headless --export-release Web build/web/index.html` then `godot --headless --main-pack build/web/index.pck -s tests/check_pack.gd`
Expected: `13 rooms, 0 failed` and `section ok`.

- [ ] **Step 5: Commit**

```bash
git add tests/playtest.gd tests/check_pack.gd
git commit -m "Playtest and pack check run against the section"
```

### Task 6: The ring housing turns

**Files:**
- Create: `scripts/ring_housing.gd`, `tests/test_ring_housing.gd`
- Modify: `tools/build_rooms.py` (`ring_deck`, `control_room`), regenerate scenes

**Interfaces:**
- Produces: `class_name RingHousing extends Node2D` with `const SLIDE := 40.0`, `const PERIOD := 192.0`, `@export var width: float = 1152.0`, `var offset: float = 0.0`; draws arc segments every `PERIOD` px along `width` in `_draw()`, shifted by `offset`; `_process` advances `offset` by `SLIDE * delta` modulo `PERIOD` while `WorldState.ring_on` and redraws.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_the_housing_slides_while_the_ring_turns_and_stops_when_it_stops() -> void:
	var h: RingHousing = add(load("res://scripts/ring_housing.gd").new())
	h.width = 1152.0
	await physics_frames(10)
	assert_true(h.offset > 0.0 and h.offset < RingHousing.PERIOD, "moved, wrapped: %f" % h.offset)
	WorldState.set_ring(false)
	await physics_frames(1)
	var stopped := h.offset
	await physics_frames(10)
	assert_eq(h.offset, stopped, "stopped dead")

func test_ring_deck_and_control_room_carry_a_housing() -> void:
	for name in ["RingDeck", "ControlRoom"]:
		var r: Room = add(load(Game.scene_path(name)).instantiate())
		var found := r.find_children("*", "RingHousing", true, false)
		assert_eq(found.size(), 1, "%s has one housing" % name)
		if not found.is_empty():
			assert_true(found[0].width >= r.bounds().size.x - 64.0, "%s housing spans the room" % name)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=ring_housing godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: fails to parse, `RingHousing` not declared.

- [ ] **Step 3: Implement and generate**

Write `scripts/ring_housing.gd` per the Interfaces block; `_draw` draws, for each segment, the same seven-point arc the generator drew (90 px wide, 60 px tall), in the generator's scenery colour, from `x = -PERIOD + offset` to `width + PERIOD` so the band is seamless at both ends. In `build_rooms.py`, replace the `ring_deck()` arc loop with `r.node('[node name="RingHousing" type="Node2D" parent="."]\nposition = Vector2(32, 60)\nscript = %s\nwidth = %s\n\n' % (r.res("res://scripts/ring_housing.gd", "Script"), f(r.w - 64)))`; add the same to `control_room()`. Rerun the generator.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/ring_housing.gd scripts/ring_housing.gd.uid tests/test_ring_housing.gd tools/build_rooms.py scenes/rooms
git commit -m "Ring housing: the band along the Ring Deck and Control Room slides while the ring turns"
```

### Task 7: The Locker porthole, live

**Files:**
- Create: `scenes/Porthole.tscn`, `scripts/porthole.gd`, `tests/test_porthole.gd`
- Modify: `tools/build_rooms.py` (`locker`), regenerate; `tests/playtest.gd` (one screenshot)

**Interfaces:**
- Consumes: `Section.room`, `Room.bounds()`.
- Produces: `class_name Porthole extends Node2D` with `@export var target_room: String = "Control Room"`, `const SIZE := Vector2i(200, 140)`, `const ZOOM := 0.35`; children `Frame: Polygon2D`, `SubViewport` (size `SIZE`, `render_target_update_mode = 3` always, `disable_3d = true`) holding `Camera2D` (zoom `ZOOM`, `enabled = true`), and `Glass: Sprite2D` drawing the viewport texture. `func aim() -> bool` points the camera at the target room's centre when a `Section` ancestor has it, returning whether it did.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_the_porthole_shares_the_world_and_aims_at_the_control_room() -> void:
	var s: Section = add(Section.new())
	await physics_frames(1)
	var port: Porthole = s.room("Locker").get_node("ViewPort")
	assert_true(port.get_node("SubViewport").world_2d == port.get_viewport().world_2d, "one world, two cameras")
	var cam: Camera2D = port.get_node("SubViewport/Camera2D")
	assert_true(cam.global_position.is_equal_approx(s.room("Control Room").bounds().get_center()), "aimed at the Control Room, at %s" % cam.global_position)
	assert_true(cam.zoom.is_equal_approx(Vector2(Porthole.ZOOM, Porthole.ZOOM)), "zoomed")

func test_a_porthole_without_a_section_stays_quiet() -> void:
	var r: Room = add(load(Game.scene_path("Locker")).instantiate())
	await physics_frames(1)
	var port: Porthole = r.get_node("ViewPort")
	assert_true(not port.aim(), "nothing to aim at")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST_FILTER=porthole godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: fails to parse, `Porthole` not declared.

- [ ] **Step 3: Implement**

`scripts/porthole.gd`: in `_ready`, set `$SubViewport.world_2d = get_viewport().world_2d`, `$Glass.texture = $SubViewport.get_texture()`, then `aim.call_deferred()` (the Control Room is added after the Locker). `aim()` walks up to a `Section` ancestor, finds `target_room`, sets `$SubViewport/Camera2D.global_position` to its bounds' centre. Build `scenes/Porthole.tscn` per the Interfaces block, the frame as the Locker's today (220 by 160 scenery) with the 200 by 140 glass inside. In `build_rooms.py` `locker()`, replace the painted `ViewPort` node text with `r.instance("ViewPort", "res://scenes/Porthole.tscn", props={"position": "Vector2(980, 300)"})`. Rerun the generator.

- [ ] **Step 4: Run the whole suite and the playtest**

Add to `_required_path` in `tests/playtest.gd`, in the `"Vent Room"` branch before the walk to the panel: `game.place("Locker", "up")`, `await frames(30)`, `await shot("Locker porthole")`, `game.place("Vent Room", "down")`, `await frames(5)`.
Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd` then `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`
Expected: all pass; the Locker screenshot shows the Control Room's floor, panel and a hovering Warden in the window.

- [ ] **Step 5: Probe the web build**

Export (`godot --headless --export-release Web build/web/index.html`), serve `build/web` on a local port, open `index.html?room=Locker&ring=off` in Playwright with the Chromium at `/opt/pw-browsers`, wait 5 s, screenshot. Expected: the window shows the Control Room, not a blank quad. If it is blank, keep the Porthole scene but restore the generator's painted `ViewPort` in `locker()`, delete the porthole screenshot step, note the failure in the commit message, and go on.

- [ ] **Step 6: Commit**

```bash
git add scenes/Porthole.tscn scripts/porthole.gd scripts/porthole.gd.uid tests/test_porthole.gd tools/build_rooms.py scenes/rooms tests/playtest.gd
git commit -m "Locker porthole: a live view of the Control Room through a second camera"
```

### Task 8: Docs, review, push

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md` (the slice table)

- [ ] **Step 1: Update the docs**

README: the section is one scene; doorways scroll; the camera looks a third of a screen past a door; the Locker's window is live. Slice design table: Control Room is one cell; the Locker's view port is a live view; Spine East to Vent Room is three steps down and three jumps up.

- [ ] **Step 2: Run everything**

Run: the suite, the playtest, the export and the pack check as in Tasks 4, 5.
Expected: all green; the Pages workflow's pack check passes after the push.

- [ ] **Step 3: Commit and push**

```bash
git add README.md docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md
git commit -m "Docs: the section as one scene"
git push -u origin ccr-baf250ca-nwpoa1
```

- [ ] **Step 4: Whole-branch review**

Review every commit since the spec against the spec, fix what the review finds, rerun everything, push.
