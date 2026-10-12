extends SceneTree

## Playtest runner: plays scripted scenarios in the real game with real key
## events, checks the outcome and saves a screenshot per step to
## playtest_out/. Needs a display, so run it under a virtual one:
##   xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd
## CI runs it on every pull request and attaches the screenshots.
## Exits 1 if any scenario fails.

const OUT_DIR := "res://playtest_out"
const SAVE_PATH := "user://playtest_save.cfg"
const VENT_BRANCH := ["Vent Room", "Locker", "Workshop", "Hangar"]

var game: Game
var failures: Array[String] = []
var _scenario: String = ""
var _shot_index: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scenarios := [
		["required_path", _required_path],
		["death_and_respawn", _death_and_respawn],
		["every_room_every_state", _every_room_every_state],
	]
	var failed := 0
	for entry in scenarios:
		_scenario = entry[0]
		_shot_index = 0
		failures.clear()
		TestHooks.reset(SAVE_PATH) # each scenario starts from the same hooks
		await entry[1].call()
		_end_game()
		if failures.is_empty():
			print("  ok    ", _scenario)
		else:
			failed += 1
			print("  FAIL  ", _scenario)
			for f in failures:
				print("          ", f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Sfx.stop_all()
	OS.delay_msec(100)
	for i in range(80):
		await physics_frame
	print("%d scenarios, %d failed; screenshots in playtest_out/" % [scenarios.size(), failed])
	quit(1 if failed > 0 else 0)

# --- helpers -------------------------------------------------------------

func _start_game() -> void:
	paused = false
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await frames(5)

func _end_game() -> void:
	for key in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_X, KEY_C, KEY_SPACE, KEY_SHIFT]:
		key_event(key, false)
	paused = false
	if is_instance_valid(game):
		root.remove_child(game)
		game.free()
	for child in root.get_children():
		if child is Room or child is Camera2D:
			root.remove_child(child)
			child.free()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func key_event(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func tap(code: int) -> void:
	key_event(code, true)
	await frames(3)
	key_event(code, false)
	await frames(3)

## Holds the keys for the given number of physics frames (60 per second).
func hold(codes: Array, count: int) -> void:
	for code in codes:
		key_event(code, true)
	await frames(count)
	for code in codes:
		key_event(code, false)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func shot(label: String) -> void:
	await process_frame
	await process_frame
	_shot_index += 1
	var path := "%s/%s_%d_%s.png" % [OUT_DIR, _scenario, _shot_index, label.replace(" ", "_")]
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

## Puts the player beside a node, facing it, and swings at it with a real key.
func swing_at(target: Node2D, from_side: int) -> void:
	game.player.global_position = target.global_position + Vector2(from_side * (Swing.REACH + 4), 0)
	game.player.velocity = Vector2.ZERO
	game.player.facing = -from_side
	await frames(2)
	await tap(KEY_X)
	await frames(8)

# --- scenarios ------------------------------------------------------------

## Dock to Exit by the designed path, flipping the switches where the design flips them.
func _required_path() -> void:
	await _start_game()
	game.start()
	await frames(5)
	check(game.room.room_name == "Dock", "starts in the Dock")
	await shot("Dock")
	var path := WorldGraph.REQUIRED_PATH
	for i in range(path.size() - 1):
		var edge := WorldGraph.EDGES.filter(func(e): return e[0] == path[i] and e[2] == path[i + 1])
		check(not edge.is_empty(), "an edge from %s to %s" % [path[i], path[i + 1]])
		if edge.is_empty():
			return
		game.enter(edge[0][2], edge[0][3])
		await frames(5)
		check(game.room.room_name == path[i + 1], "entered %s" % path[i + 1])
		match game.room.room_name:
			"Blister":
				var panel: Switch = game.room.find_children("*", "Switch", true, false)[0]
				await swing_at(panel, 1)
				check(not WorldState.ring_on, "the Blister's panel stops the ring")
				await shot("Blister ring off")
			"Vent Room":
				var panel: Switch = game.room.find_children("*", "Switch", true, false)[0]
				await hold([KEY_D], 190) # walk the length of the room to the panel
				await swing_at(panel, -1)
				check(WorldState.vents_open, "the Vent Room's panel opens the vents")
				await shot("Vent Room vents open")
			"Control Room":
				var warden := game.room.find_children("*", "Warden", true, false)
				check(warden.size() == 1, "the Warden is there")
				await shot("Control Room")
				if warden.size() == 1:
					warden[0].damage(Warden.MAX_HEALTH_WARDEN, game.player.global_position, false)
				await frames(5)
				check(WorldState.boss_down, "the Warden is down")
				await shot("Control Room door open")
			"Exit":
				await hold([KEY_D], 240)
				check(paused, "the slice ends")
				var end := game.room.find_children("*", "SliceEnd", true, false)[0]
				check(end.get_node("Screen").visible, "the end screen shows")
				await shot("Exit end")
			_:
				await shot(game.room.room_name)

## Rest at the Ring Deck airlock, die in the Hangar's gale, wake at the airlock with the switches unchanged.
func _death_and_respawn() -> void:
	await _start_game()
	game.enter("Ring Deck", "east")
	await frames(5)
	await swing_at(game.room.checkpoint(), 1)
	check(WorldState.checkpoint == "Ring Deck", "rested at the Ring Deck airlock")
	await shot("rested")
	WorldState.set_ring(false)
	WorldState.set_vents(true)
	game.enter("Hangar", "up")
	await frames(5)
	game.player.global_position.y = 400 # in the gale, level with the shredded wall
	game.player.velocity = Vector2.ZERO
	await shot("in the gale")
	var waited := 0
	while not game.player.dead and waited < 600:
		await frames(10)
		waited += 10
	check(game.player.dead, "the gale carried the player into the hazards")
	await shot("dead")
	await frames(int(Player.DEATH_DELAY * 60) + 10)
	check(game.room.room_name == "Ring Deck", "back on the Ring Deck")
	check(not game.player.dead and game.player.health == Player.MAX_HEALTH, "alive and whole")
	check(game.player.global_position.distance_to(game.room.checkpoint().spawn_point()) < 2.0, "at the airlock")
	check(not WorldState.ring_on and WorldState.vents_open, "switches as they were left")
	await shot("respawned")

## Every room in every state it is designed for, whole room in frame.
func _every_room_every_state() -> void:
	for name in WorldGraph.ROOMS:
		var states := [[true, false], [false, false]]
		if VENT_BRANCH.has(name):
			states = [[true, false], [false, false], [true, true], [false, true]]
		for state in states:
			WorldState.reset()
			WorldState.set_ring(state[0])
			WorldState.set_vents(state[1])
			var r: Room = load(Game.scene_path(name)).instantiate()
			root.add_child(r)
			var cam := Camera2D.new()
			var b := r.bounds()
			cam.position = b.get_center()
			var z := minf(1152.0 / b.size.x, 648.0 / b.size.y)
			cam.zoom = Vector2(z, z)
			root.add_child(cam)
			cam.make_current()
			await frames(10)
			check(r.compartment.has_gravity() == (state[0] and r.compartment.plates_live), "%s gravity follows the ring" % name)
			await shot("%s ring %s vents %s" % [name, "on" if state[0] else "off", "open" if state[1] else "closed"])
			root.remove_child(r)
			r.free()
			root.remove_child(cam)
			cam.free()
	WorldState.reset()
