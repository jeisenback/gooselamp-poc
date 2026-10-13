extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func _first_shape(node: Node) -> CollisionShape2D:
	return node.find_children("*", "CollisionShape2D", true, false)[0]

func test_vent_room_locker_hatch_needs_vents_closed_and_ring_off() -> void:
	var r := _room("VentRoom")
	await physics_frames(1)
	var hatch := _first_shape(r.get_node("Compartment/VentsOpen"))
	var cabinet := _first_shape(r.get_node("Compartment/RingOn"))
	assert_true(hatch.disabled and not cabinet.disabled, "start: hatch open, cabinet blocks")
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(hatch.disabled and cabinet.disabled, "ring off: the way down is open")
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(not hatch.disabled, "vents open: hatch shut")
	assert_eq(r.find_children("*", "Switch", true, false)[0].switch_name, "vents", "the vents panel")

func test_workshop_has_clingers_and_an_east_wind() -> void:
	var r := _room("Workshop")
	await physics_frames(1)
	var spawners := r.find_children("*", "Spawner", true, false)
	assert_eq(spawners.size(), 3, "three")
	assert_true(spawners.all(func(s): return s.spawned is Clinger), "all clingers")
	var vent: Vent = r.find_children("*", "Vent", true, false)[0]
	assert_true(vent.direction.is_equal_approx(Vector2.RIGHT), "east")

func test_spine_east_floor_is_higher_than_spine_west() -> void:
	var east := _room("SpineEast")
	var west := _room("SpineWest")
	assert_true(west.floor_y - east.floor_y >= 200.0, "a drop from east to west, never a jump: %f" % (west.floor_y - east.floor_y))

func test_locker_is_quiet_and_has_the_view_port() -> void:
	var r := _room("Locker")
	await physics_frames(1)
	assert_true(r.find_children("*", "Spawner", true, false).is_empty(), "no enemies")
	assert_true(r.get_node_or_null("ViewPort") != null, "the secret")

func test_vent_room_steps_climb_to_spine_east_s_door() -> void:
	var r := _room("VentRoom")
	var door_bottom := r.exit_named("west").global_position.y + 68.0
	var last_top := r.floor_y
	for i in range(3):
		var step := r.get_node("Hull/Step%d" % i) as CollisionShape2D
		var top := step.position.y - (step.shape as RectangleShape2D).size.y / 2.0
		assert_true(last_top - top >= 60.0 and last_top - top <= 80.0, "step %d rises %f" % [i, last_top - top])
		assert_true((step.shape as RectangleShape2D).size.x >= 80.0, "step %d is wide enough to land on" % i)
		last_top = top
	assert_true(absf(last_top - door_bottom) <= 8.0, "the top step is the door's sill")
