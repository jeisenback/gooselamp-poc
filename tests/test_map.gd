extends TestCase

func test_map_draws_visited_rooms_and_their_panels() -> void:
	var g: Game = add(load("res://scenes/Main.tscn").instantiate())
	g.player.input_override = PlayerInput.new()
	g.place("Dock", "west")
	g.place("Breach", "east")
	g.place("Blister", "east")
	await physics_frames(1)
	var map: Map = g.get_node("Map")
	assert_true(not map.visible, "hidden until toggled")
	map.toggle()
	await physics_frames(1)
	assert_true(map.visible, "shown")
	assert_eq(map.boxes_drawn(), 3, "three visited")
	assert_eq(map.panels_marked(), 1, "the Blister's panel")

func test_map_toggles_while_dead() -> void:
	var g: Game = add(load("res://scenes/Main.tscn").instantiate())
	g.player.input_override = PlayerInput.new()
	g.place("Dock", "west")
	await physics_frames(1)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	g.get_node("Map").toggle()
	await physics_frames(1)
	assert_true(g.get_node("Map").visible, "open")
