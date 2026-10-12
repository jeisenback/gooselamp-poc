extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func test_blister_holds_ring_panel_two_and_stops_the_ring() -> void:
	var r := _room("Blister")
	await physics_frames(1)
	var panels := r.find_children("*", "Switch", true, false)
	assert_eq(panels.size(), 1, "one panel")
	assert_eq(panels[0].switch_name, "ring", "the ring")
	assert_true(not r.compartment.plates_live, "dead plates")
	var ring: Node2D = r.get_node("Ring")
	var before := ring.rotation
	await physics_frames(10)
	assert_true(ring.rotation != before, "turning")
	WorldState.set_ring(false)
	await physics_frames(2)
	var stopped := ring.rotation
	await physics_frames(10)
	assert_eq(ring.rotation, stopped, "stopped")

func test_spine_west_gate_blocks_only_in_gravity() -> void:
	var r := _room("SpineWest")
	await physics_frames(1)
	var gate_shape: CollisionShape2D = r.get_node("Compartment/RingOn").find_children("*", "CollisionShape2D", true, false)[0]
	assert_true(not gate_shape.disabled, "gate solid with the ring on")
	var east := r.exit_named("east")
	var floor_y := r.floor_y
	assert_true(floor_y - east.global_position.y >= 200.0, "the east exit is a gravity-blocking height above the floor")
	assert_true(r.exit_named("up").global_position.y <= floor_y - 400.0, "the shaft mouth is well above")
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(gate_shape.disabled, "gate gone in zero-g")

func test_shaft_door_follows_the_vents() -> void:
	var r := _room("Shaft")
	await physics_frames(1)
	var door: CollisionShape2D = r.get_node("Compartment/VentsClosed").find_children("*", "CollisionShape2D", true, false)[0]
	assert_true(not door.disabled, "sealed")
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(door.disabled, "open")
	assert_true(r.exit_named("up").global_position.y < r.exit_named("down").global_position.y - 1000.0, "two cells tall")
