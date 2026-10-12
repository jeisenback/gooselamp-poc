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
	await physics_frames(frame_count(Game.SWAP_COOLDOWN))
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
