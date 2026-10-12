extends TestCase

func test_a_hit_flips_its_switch_once_per_swing() -> void:
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.switch_name = "vents"
	assert_true(s.is_in_group(Groups.HITTABLE), "hittable")
	s.hit(null, Vector2.RIGHT)
	assert_true(WorldState.vents_open, "opened")
	s.hit(null, Vector2.RIGHT)
	assert_true(WorldState.vents_open, "a second hit inside the delay is ignored")
	await physics_frames(int(Switch.REHIT_DELAY * 60) + 2)
	s.hit(null, Vector2.RIGHT)
	assert_true(not WorldState.vents_open, "closed again")

func test_the_ring_switch_flips_the_ring() -> void:
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.hit(null, Vector2.LEFT)
	assert_true(not WorldState.ring_on, "ring off")
