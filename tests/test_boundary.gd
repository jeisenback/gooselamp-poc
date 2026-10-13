extends TestCase

## Two rooms side by side sharing an open boundary at x = 0: left has live plates and a floor, right has dead plates.
func _two_rooms() -> Dictionary:
	var left := make_room(true, Vector2(1000, 600), Vector2(-500, 0))
	var right := make_room(false, Vector2(1000, 600), Vector2(500, 0))
	# Open the shared wall: drop the left room's right wall and the right room's left wall.
	left.room.get_node("Walls/Right").queue_free()
	right.room.get_node("Walls/Left").queue_free()
	right.room.get_node("Walls/Floor").queue_free()
	return {"left": left, "right": right}

func test_running_off_a_plate_keeps_going_straight() -> void:
	var rooms := _two_rooms()
	await physics_frames(1)
	var p := spawn_player(Vector2(-100, rooms.left.floor_y - 30))
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(1.5))
	assert_true(p.global_position.x > 50.0, "crossed into the dead room")
	assert_true(p.in_zero_g(), "zero-g on the far side")
	assert_true(absf(p.velocity.y) < 1.0, "no fall, got vy %f" % p.velocity.y)
	assert_true(p.velocity.x >= Player.RUN_SPEED - 1.0, "run speed carried across (the held stick thrusts on from there), got %f" % p.velocity.x)

func test_flying_into_gravity_arcs_and_lands() -> void:
	var rooms := _two_rooms()
	await physics_frames(1)
	var p := spawn_player(Vector2(200, rooms.left.floor_y - 200))
	p.velocity = Vector2(-300, 0)
	await physics_frames(frame_count(1.5))
	assert_true(not p.in_zero_g(), "in the live room")
	assert_true(p.is_on_floor(), "landed")

func test_outside_every_compartment_is_zero_g() -> void:
	var p := spawn_player(Vector2(0, 0))
	await physics_frames(2)
	assert_true(p.tracker.compartments.is_empty(), "no compartment")
	assert_true(p.in_zero_g(), "space is zero-g")
	p.velocity = Vector2(10, 10)
	await physics_frames(10)
	assert_true(p.velocity.is_equal_approx(Vector2(10, 10)), "and nothing falls")

func test_leaving_one_of_two_overlapping_compartments_keeps_the_other() -> void:
	var live := make_room(true, Vector2(600, 600), Vector2(0, 0))
	var dead := make_room(false, Vector2(600, 600), Vector2(400, 0))
	dead.room.get_node("Walls").queue_free()
	live.room.get_node("Walls").queue_free()
	await physics_frames(1)
	var p := spawn_player(Vector2(200, 0))   # inside both
	await physics_frames(2)
	assert_eq(p.tracker.compartments.size(), 2, "in both")
	p.global_position = Vector2(550, 0)        # only the dead room now
	await physics_frames(2)
	assert_eq(p.tracker.compartments.size(), 1, "left the live room")
	assert_true(p.in_zero_g(), "the remaining one rules")

func test_the_last_compartment_entered_rules_an_overlap() -> void:
	var live := make_room(true, Vector2(600, 600), Vector2(0, 0))
	var dead := make_room(false, Vector2(600, 600), Vector2(400, 0))
	dead.room.get_node("Walls").queue_free()
	live.room.get_node("Walls").queue_free()
	await physics_frames(1)
	var p := spawn_player(Vector2(-100, 0))   # live only
	await physics_frames(2)
	assert_true(not p.in_zero_g(), "gravity in the live room alone")
	p.global_position = Vector2(200, 0)        # into the overlap: dead entered last
	await physics_frames(2)
	assert_eq(p.tracker.compartments.size(), 2, "in both")
	assert_true(p.in_zero_g(), "the dead room, entered last, rules")

func test_rising_into_gravity_keeps_its_upward_speed() -> void:
	var rooms := _two_rooms()
	await physics_frames(1)
	var p := spawn_player(Vector2(40, rooms.left.floor_y - 200))
	p.velocity = Vector2(-300, -300)
	await physics_frames(10)
	assert_true(not p.in_zero_g(), "in the live room")
	assert_true(p.velocity.y < -180.0, "still rising at nearly the speed it arrived with, got vy %f" % p.velocity.y)
