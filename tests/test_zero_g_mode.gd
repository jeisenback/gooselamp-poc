extends TestCase

func test_drift_never_decays_and_nothing_falls() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(-400, 0))
	p.velocity = Vector2(100, -40)
	await physics_frames(frame_count(1.0))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -40)), "velocity unchanged, got %s" % p.velocity)
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.5))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -40)), "aim alone does not steer")

func test_hitting_a_wall_stops_you() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	await physics_frames(frame_count(1.0))
	assert_true(absf(p.velocity.x) < 1.0, "stopped by the right wall")
	assert_true(not p.grabbed, "not grabbed without the button")

func test_grab_holds_and_release_leaves_you_at_rest() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 300)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	assert_true(p.grabbed, "grabbed the wall")
	assert_eq(p.velocity, Vector2.ZERO, "dead stop")
	assert_true(p.grab_normal.is_equal_approx(Vector2.LEFT), "normal points back into the room")
	var held_at := p.global_position
	await physics_frames(10)
	assert_eq(p.global_position, held_at, "does not slide while held")
	p.input_override.grab_held = false
	await physics_frames(10)
	assert_true(not p.grabbed and p.velocity == Vector2.ZERO, "released, at rest")

func test_kick_from_a_grab_in_the_aimed_direction_or_along_the_normal() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	p.input_override.aim = Vector2(-1, -1).normalized()
	p.input_override.jump_pressed = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(p.velocity.is_equal_approx(Vector2(-1, -1).normalized() * Player.KICK_SPEED), "kick along the aim")
	assert_true(not p.grabbed, "let go")
	p.velocity = Vector2(400, 0)
	p.input_override.aim = Vector2.ZERO
	await physics_frames(frame_count(1.0))
	p.input_override.jump_pressed = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(p.velocity.is_equal_approx(Vector2.LEFT * Player.KICK_SPEED), "no aim: kick along the normal")

func test_jump_in_open_space_does_nothing() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	p.input_override.jump_pressed = true
	await physics_frames(1)
	assert_eq(p.velocity, Vector2.ZERO, "no thruster on jump")

func test_fire_recoils_once_per_cooldown() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	p.input_override.aim = Vector2.UP
	p.input_override.fire_pressed = true
	await physics_frames(frame_count(Player.FIRE_COOLDOWN) - 2)
	assert_true(p.velocity.is_equal_approx(Vector2.DOWN * Player.RECOIL_SPEED), "one recoil, got %s" % p.velocity)
	await physics_frames(4)
	assert_true(p.velocity.is_equal_approx(Vector2.DOWN * Player.RECOIL_SPEED * 2), "second recoil after the cooldown")

func test_fire_breaks_a_grab() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(1)
	assert_true(not p.grabbed, "firing lets go")
	assert_true(p.velocity.is_equal_approx(Vector2.LEFT * Player.RECOIL_SPEED), "pushed off the wall")

func test_kick_along_the_grabbed_surface_lets_go() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	assert_true(p.grabbed, "grabbed the right wall")
	p.input_override.aim = Vector2.UP
	p.input_override.jump_pressed = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	await physics_frames(5)
	assert_true(not p.grabbed, "still going, not re-latched by the wall it is sliding along")
	assert_true(p.velocity.is_equal_approx(Vector2.UP * Player.KICK_SPEED), "kicked up along the wall, got %s" % p.velocity)
