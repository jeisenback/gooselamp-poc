extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func _first_shape(node: Node) -> CollisionShape2D:
	return node.find_children("*", "CollisionShape2D", true, false)[0]

func test_hangar_ceiling_is_zero_g_only_and_the_wind_meets_hazards() -> void:
	var r := _room("Hangar")
	await physics_frames(1)
	assert_true(r.floor_y - r.exit_named("up").global_position.y >= 1000.0, "far above")
	var hazards := r.find_children("*", "Hazard", true, false)
	var vent: Vent = r.find_children("*", "Vent", true, false)[0]
	assert_true(hazards.size() >= 3 and vent.direction.is_equal_approx(Vector2.RIGHT), "shredded wall downwind")
	assert_true(hazards.all(func(h): return h.global_position.x > r.bounds().get_center().x), "hazards on the east")
	var hatch := _first_shape(r.get_node("Compartment/VentsClosed"))
	assert_true(not hatch.disabled, "hatch shut at start")

func test_ring_deck_has_the_second_airlock_and_both_floor_openings() -> void:
	var r := _room("RingDeck")
	await physics_frames(1)
	assert_eq(r.checkpoint().room_name, "Ring Deck", "airlock")
	assert_true(r.exit_named("down_west").global_position.x < r.exit_named("down_east").global_position.x, "west then east")
	assert_true(r.bounds().size.x >= 6 * 1152 - 1, "six cells")

func test_control_room_holds_panel_one_the_warden_and_the_door() -> void:
	var r := _room("ControlRoom")
	await physics_frames(1)
	assert_eq(r.find_children("*", "Switch", true, false)[0].switch_name, "ring", "panel one")
	assert_true(r.find_children("*", "Spawner", true, false)[0].spawned is Warden, "the Warden")
	assert_true(r.bounds().size.y >= 600.0 + 64.0, "room for the hover height")
	var door := _first_shape(r.get_node("Compartment/BossAlive"))
	assert_true(not door.disabled, "door shut")
	WorldState.set_boss_down()
	await physics_frames(1)
	assert_true(door.disabled, "door open for good")

func test_the_exit_ends_the_slice() -> void:
	var r := _room("Exit")
	await physics_frames(1)
	var end: SliceEnd = r.find_children("*", "SliceEnd", true, false)[0]
	var p := spawn_player(end.global_position)
	await physics_frames(3)
	assert_true(tree.paused, "paused at the end")
	assert_true(end.get_node("Screen").visible, "the end screen")
	tree.paused = false
