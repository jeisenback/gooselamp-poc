extends TestCase

func _game() -> Game:
	var g: Game = load("res://scenes/Main.tscn").instantiate()
	add(g)
	g.player.input_override = PlayerInput.new() # scripted input, never the keyboard
	return g

func test_starts_in_the_dock_with_nothing_saved() -> void:
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.room.room_name, "Dock", "the Dock")
	assert_true(Array(WorldState.visited).has("Dock"), "visited")
	assert_true(g.player.global_position.distance_to(g.room.checkpoint().spawn_point()) < 2.0, "at the airlock")
	assert_eq(g.get_node("Camera2D").limit_right, int(g.room.bounds().end.x), "camera limited to the room")

func test_crossing_an_exit_swaps_rooms_and_keeps_velocity() -> void:
	var g := _game()
	g.enter("Dock", "west")
	await physics_frames(2)
	var west := g.room.exit_named("west")
	g.player.global_position = west.global_position + west.inward * 20.0
	g.player.velocity = Vector2(-150, 0)
	g.player.input_override.aim = Vector2.LEFT
	await physics_frames(frame_count(0.5))
	assert_eq(g.room.room_name, "Breach", "swapped")
	assert_true(g.player.velocity.x < -100.0, "still moving left, got %s" % g.player.velocity)
	assert_true(g.player.in_zero_g(), "the Breach is zero-g")
	g.player.velocity = Vector2.ZERO # stop dead at the arrival point: it must be clear of the exit
	await physics_frames(frame_count(Game.SWAP_COOLDOWN) + 2)
	assert_eq(g.room.room_name, "Breach", "did not bounce back through the arrival exit")

func test_only_the_player_crosses() -> void:
	var g := _game()
	g.enter("Dock", "west")
	await physics_frames(2)
	var east := g.room.exit_named("east")
	var m: Mite = add(load("res://scenes/Mite.tscn").instantiate())
	m.global_position = east.global_position
	Shot.spawn(tree.root, null, east.global_position, Vector2.ZERO, false)
	await physics_frames(5)
	assert_eq(g.room.room_name, "Dock", "still the Dock")

func test_a_save_naming_a_missing_room_falls_back_to_the_dock() -> void:
	WorldState.set_checkpoint("Boiler Deck")
	WorldState.save()
	WorldState.reset()
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.room.room_name, "Dock", "fell back")

func test_death_before_resting_returns_to_the_dock_airlock() -> void:
	var g := _game()
	g.enter("Breach", "west")
	await physics_frames(2)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	assert_eq(g.room.room_name, "Dock", "back at the Dock")
	assert_true(not g.player.dead, "alive")

func test_boss_containers_follow_the_flag() -> void:
	var c: Compartment = add(load("res://scenes/Compartment.tscn").instantiate())
	for n in ["BossAlive", "BossDown"]:
		var h := Node2D.new()
		h.name = n
		c.add_child(h)
	await physics_frames(1)
	assert_true(c.get_node("BossAlive").visible and not c.get_node("BossDown").visible, "alive")
	WorldState.set_boss_down()
	await physics_frames(1)
	assert_true(not c.get_node("BossAlive").visible and c.get_node("BossDown").visible, "down")

func test_a_dead_body_does_not_cross_an_exit() -> void:
	var g := _game()
	g.enter("Breach", "west")
	await physics_frames(2)
	var east := g.room.exit_named("east")
	g.player.global_position = east.arrival_point() + east.inward * 10.0
	g.player.velocity = -east.inward * 200.0
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	g.player.velocity = -east.inward * 200.0
	await physics_frames(frame_count(0.5))
	assert_eq(g.room.room_name, "Breach", "the dead drift, they do not travel")

## Every edge the graph gates is shut in the real rooms when its needs fail: a
## player pushed at the doorway from either side stays in the room, well
## inside its bounds. The geometry, not only the controller, must hold.
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
			g.enter(e[0], "")
			await physics_frames(2)
			var exit := g.room.exit_named(e[1])
			var inward: Vector2 = exit.inward # copied: a leaking door would swap the room and free the exit
			g.player.global_position = exit.arrival_point() + inward * 20.0
			g.player.velocity = -inward * 220.0
			g.player.input_override.aim = -inward
			g.player.input_override.grab_held = false
			for i in range(frame_count(0.6)):
				await physics_frames(1)
				if g.player.in_zero_g():
					g.player.velocity = -inward * 220.0 # keep pushing at the door
			var label := "%s %s with ring_on=%s vents_open=%s boss_down=%s" % [e[0], e[1], state.ring_on, state.vents_open, state.boss_down]
			assert_eq(g.room.room_name, e[0], "%s: stays in the room" % label)
			assert_true(g.room.bounds().grow(-40.0).has_point(g.player.global_position), "%s: held well inside the room, at %s" % [label, g.player.global_position])
			g.player.input_override.aim = Vector2.ZERO
