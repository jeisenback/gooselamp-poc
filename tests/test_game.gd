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
	g.player.global_position = east.global_position - east.inward * 20.0 # a leak: the centre is past the hull's outer face
	g.player.velocity = Vector2(300, 0)
	await physics_frames(6) # the area reports the overlap a tick late; the set-back and the tracker's correction follow
	assert_eq(g.current.room_name, "Spine West", "held")
	assert_true(absf(g.player.global_position.x - east.arrival_point().x) < 2.0 and g.player.velocity.x == 0.0, "set back at the arrival point, stopped (gravity may have begun to act since)")

## Spine East to Spine West is open in every state; only the way back needs
## the ring off. In a shared doorway the body overlaps both rooms' exits,
## and the shut one must not misread an arrival as a leak.
func test_a_one_way_doorway_does_not_interrupt_the_open_direction() -> void:
	var g := _game()
	g.place("Spine East", "west")
	await physics_frames(2)
	g.player.velocity = Vector2(-150, 0)
	g.player.input_override.aim = Vector2.LEFT
	var last := g.player.global_position
	var biggest := 0.0
	for i in range(frame_count(0.6)):
		await physics_frames(1)
		biggest = maxf(biggest, g.player.global_position.distance_to(last))
		last = g.player.global_position
	assert_eq(g.current.room_name, "Spine West", "dropped into Spine West")
	assert_true(biggest < 12.0, "never set back, biggest step %f" % biggest)
	assert_true(g.player.global_position.x < g.current.bounds().end.x - 60.0, "well inside, at %s" % g.player.global_position)

func test_a_save_naming_a_missing_room_falls_back_to_the_dock() -> void:
	WorldState.set_checkpoint("Boiler Deck")
	WorldState.save()
	WorldState.reset()
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.current.room_name, "Dock", "fell back")

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
	assert_eq(g.current.room_name, "Locker", "the Locker")
	assert_true(g.player.global_position.distance_to(g.current.exits()[0].arrival_point()) < 2.0, "at the hatch (before gravity and the cabinet above move the body)")

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
			if g.player.dead:
				g.player.respawn(g.player.global_position)
				g.get_node("Respawner")._countdown = -1.0
			g.player.heal_full() # each edge on its own: mites met on earlier pushes do not carry over
			g.place(e[0], e[1])
			await physics_frames(2)
			var room := g.current
			var exit := room.exit_named(e[1])
			var inward: Vector2 = exit.inward
			if g.player.in_zero_g():
				g.player.global_position = exit.arrival_point() + inward * 20.0 # clear of the door that stands proud of the hull
			elif inward.y == 0.0:
				# on the floor, 128 px in from the hull's outer face: clear of a door (56) and of the Spine West gate (104)
				g.player.global_position = Vector2(exit.global_position.x + inward.x * 128.0, room.global_position.y + room.floor_y - 24.0)
			else:
				# above or below the doorway, clear of the cabinet that stands 100 px tall on the Vent Room's hatch
				g.player.global_position = exit.arrival_point() + inward * 120.0
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
			assert_true(not g.player.dead, "%s: survived the push" % label)
			g.player.input_override.aim = Vector2.ZERO
