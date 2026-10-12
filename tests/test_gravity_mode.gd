extends TestCase

func test_run_reaches_run_speed_and_stops() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x - Player.RUN_SPEED) < 1.0, "at run speed, got %f" % p.velocity.x)
	assert_eq(p.facing, 1, "facing right")
	p.input_override.aim = Vector2.ZERO
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x) < 1.0, "stopped")
	assert_true(p.is_on_floor(), "stays on the floor")

func test_full_jump_is_higher_than_a_short_hop() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(frame_count(0.25)) # the spawn is a few px up; let it land
	var start_y := p.global_position.y
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(absf(p.velocity.y + Player.JUMP_SPEED) < 1.0, "leaves at jump speed")
	var full_top := start_y
	for i in range(frame_count(1.0)):
		await physics_frames(1)
		full_top = minf(full_top, p.global_position.y)
	assert_true(p.is_on_floor(), "landed")
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	await physics_frames(3)
	p.input_override.jump_held = false
	await physics_frames(1)
	assert_true(p.velocity.y >= -Player.JUMP_CUT_SPEED - 1.0, "release caps the rise")
	var hop_top := start_y
	for i in range(frame_count(1.0)):
		await physics_frames(1)
		hop_top = minf(hop_top, p.global_position.y)
	assert_true(start_y - full_top > 80.0, "full jump clears 80 px, got %f" % (start_y - full_top))
	assert_true(start_y - hop_top < (start_y - full_top) * 0.6, "short hop is well under the full jump")

func test_jump_only_from_the_floor() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 300))
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	assert_true(p.velocity.y >= 0.0, "no jump in the air")

func test_fire_in_gravity_has_no_recoil_and_cools_down() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(frame_count(0.25))
	var shots := []
	p.fired.connect(func(d): shots.append(d))
	p.input_override.fire_pressed = true
	await physics_frames(frame_count(0.25))
	assert_eq(shots.size(), 1, "one shot in a quarter second of holding fire")
	assert_eq(shots[0], Vector2.RIGHT, "fires the way it faces when aim is zero")
	assert_true(absf(p.velocity.x) < 1.0, "no recoil in gravity")

func test_a_stale_grab_is_dropped_in_gravity() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	p.grabbed = true
	p.input_override.grab_held = true
	await physics_frames(2)
	assert_true(not p.grabbed, "gravity has no grab: a hold carried over from zero-g is dropped")
