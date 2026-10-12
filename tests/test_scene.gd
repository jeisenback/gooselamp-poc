extends TestCase

func test_the_test_room_runs_a_second_without_errors() -> void:
	var room = add(load("res://scenes/TestRoom.tscn").instantiate())
	await physics_frames(60)
	assert_true(room.player is Player, "has a player")
	assert_true(room.player.is_on_floor(), "starts on the floor of the live compartment")
	assert_eq(room.get_node("Camera2D").rotation, 0.0, "camera never rotates")
	WorldState.set_ring(false)
	await physics_frames(60)
	assert_true(room.player.in_zero_g(), "the ring switch reaches the player")

func test_the_test_room_has_enemies_an_airlock_and_a_hud() -> void:
	var room = add(load("res://scenes/TestRoom.tscn").instantiate())
	await physics_frames(5)
	assert_eq(tree.get_nodes_in_group(Groups.SPAWNER).size(), 4, "four spawners")
	assert_eq(tree.get_nodes_in_group(Groups.ENEMY).size(), 4, "four enemies alive")
	assert_eq(tree.get_nodes_in_group(Groups.CHECKPOINT).size(), 1, "one airlock")
	assert_true(room.get_node("HUD") is Hud, "hud")

func test_the_arena_runs_and_the_warden_is_there() -> void:
	var arena = add(load("res://scenes/TestArena.tscn").instantiate())
	await physics_frames(60)
	assert_true(tree.get_nodes_in_group(Groups.ENEMY).any(func(e): return e is Warden), "the Warden")
	assert_true(arena.get_node("RingSwitch") is Switch, "the switch is in the room")
