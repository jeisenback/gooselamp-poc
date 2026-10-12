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
