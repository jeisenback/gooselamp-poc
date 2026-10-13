extends TestCase

func test_the_housing_slides_while_the_ring_turns_and_stops_when_it_stops() -> void:
	var h: RingHousing = add(load("res://scripts/ring_housing.gd").new())
	h.width = 1152.0
	await physics_frames(10)
	assert_true(h.offset > 0.0 and h.offset < RingHousing.PERIOD, "moved, wrapped: %f" % h.offset)
	WorldState.set_ring(false)
	await physics_frames(1)
	var stopped := h.offset
	await physics_frames(10)
	assert_eq(h.offset, stopped, "stopped dead")

func test_ring_deck_and_control_room_carry_a_housing() -> void:
	for name in ["RingDeck", "ControlRoom"]:
		var r: Room = add(load(Game.scene_path(name)).instantiate())
		var found := r.find_children("*", "RingHousing", true, false)
		assert_eq(found.size(), 1, "%s has one housing" % name)
		if not found.is_empty():
			assert_true(found[0].width >= r.bounds().size.x - 64.0, "%s housing spans the room" % name)
