extends TestCase

func _drone(at: Vector2) -> Drone:
	var d: Drone = load("res://scenes/Drone.tscn").instantiate()
	d.position = at
	return add(d) as Drone

func test_hovers_at_height_in_gravity_and_charges_level() -> void:
	var r := make_room(true)
	var d := _drone(Vector2(0, r.floor_y - 300))
	var p := spawn_player(Vector2(-380, r.floor_y - 30))   # in range, beyond one charge's length
	await physics_frames(frame_count(Drone.WINDUP + 0.2))
	assert_true(absf(d.global_position.y - (r.floor_y - Drone.HOVER_HEIGHT)) < 4.0, "at hover height, got %f" % d.global_position.y)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	assert_true(d.velocity.x < 0.0 and absf(d.velocity.y) < 1.0, "level charge toward the player, got %s" % d.velocity)
	assert_true(absf(d.velocity.length() - Drone.CHARGE_SPEED) < 1.0, "at charge speed")

func test_charges_along_the_full_line_in_zero_g() -> void:
	var r := make_room(false)
	var d := _drone(Vector2.ZERO)
	var p := spawn_player(Vector2(200, 200))
	await physics_frames(frame_count(Drone.WINDUP) + 4)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	assert_true(d.velocity.normalized().dot(Vector2(1, 1).normalized()) > 0.999, "diagonal, got %s" % d.velocity)

func test_a_shot_cancels_the_charge() -> void:
	var r := make_room(false)
	var d := _drone(Vector2.ZERO)
	var p := spawn_player(Vector2(300, 0))
	await physics_frames(frame_count(Drone.WINDUP) + 4)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	d.damage(1, p.global_position, true)
	await physics_frames(1)
	assert_eq(d.state, Drone.State.HOVER, "cancelled")
	assert_eq(d.velocity, Vector2.ZERO, "stopped")

func test_out_of_range_it_only_hovers() -> void:
	var r := make_room(false, Vector2(3000, 1200))
	var d := _drone(Vector2(-1200, 0))
	var p := spawn_player(Vector2(1200, 0))
	await physics_frames(frame_count(1.5))
	assert_eq(d.state, Drone.State.HOVER, "hovering")
	assert_true(d.velocity.length() <= Drone.DRIFT_SPEED + 1.0, "drifting at most")
