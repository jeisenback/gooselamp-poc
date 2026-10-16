extends TestCase

func test_drift_never_decays_and_nothing_falls() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(-400, 0))
	p.velocity = Vector2(100, -40)
	await physics_frames(frame_count(1.0))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -40)), "velocity unchanged, got %s" % p.velocity)
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.5))
	assert_true(p.velocity.x > 100.0 and absf(p.velocity.y + 40.0) < 0.01, "the stick thrusts along its aim and nothing else changes, got %s" % p.velocity)
	p.input_override.aim = Vector2.ZERO
	var kept := p.velocity
	await physics_frames(frame_count(0.5))
	assert_true(p.velocity.is_equal_approx(kept), "released, the speed is kept: no drag")

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

func test_fire_has_no_recoil_and_fires_once_per_cooldown() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	var shots := []
	p.fired.connect(func(d): shots.append(d))
	p.input_override.fire_pressed = true
	await physics_frames(frame_count(Player.FIRE_COOLDOWN) - 2)
	assert_eq(shots.size(), 1, "one shot inside the cooldown")
	assert_eq(p.velocity, Vector2.ZERO, "the gun does not move you")
	await physics_frames(4)
	assert_eq(shots.size(), 2, "the second shot once the cooldown ends")

func test_fire_keeps_a_grab() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	var shots := []
	p.fired.connect(func(d): shots.append(d))
	p.input_override.fire_pressed = true
	await physics_frames(1)
	assert_eq(shots.size(), 1, "shot from cover")
	assert_true(p.grabbed and p.velocity == Vector2.ZERO, "still holding on")

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
	p.input_override.aim = Vector2.ZERO # the kick took its direction; no thrust after
	await physics_frames(5)
	assert_true(not p.grabbed, "still going, not re-latched by the wall it is sliding along")
	assert_true(p.velocity.is_equal_approx(Vector2.UP * Player.KICK_SPEED), "kicked up along the wall, got %s" % p.velocity)

func test_grab_catches_a_near_miss_within_range() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(978, 0)) # 12px short of the right wall (inside ZeroGMode.GRAB_RANGE)
	p.velocity = Vector2(5, 0) # a nudge toward the wall, just to give the catch a direction
	p.input_override.grab_held = true
	await physics_frames(1)
	assert_true(p.grabbed, "catches a wall within range even without touching it yet")
	assert_true(p.grab_normal.is_equal_approx(Vector2.LEFT), "normal points back into the room, got %s" % p.grab_normal)
	assert_eq(p.velocity, Vector2.ZERO, "stops dead once caught")
	assert_true(absf(p.global_position.x - 990.0) < 0.5, "lands on the wall, not short of it, got %s" % p.global_position)

func test_grab_does_not_catch_beyond_its_range() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(966, 0)) # 24px short of the right wall: outside ZeroGMode.GRAB_RANGE
	p.velocity = Vector2(5, 0)
	p.input_override.grab_held = true
	await physics_frames(1)
	assert_true(not p.grabbed, "too far to catch")

func test_grab_latches_on_contact_without_moving_into_the_surface() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(990, 0)) # touching the right wall already
	p.velocity = Vector2(0, 50) # sliding along it, not into it
	p.input_override.grab_held = true
	await physics_frames(1)
	assert_true(p.grabbed, "contact alone catches; moving into the wall is not required")
	assert_eq(p.velocity, Vector2.ZERO, "stops dead once caught")

func test_kick_along_a_wall_relatches_once_the_grace_period_ends() -> void:
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
	p.input_override.aim = Vector2.ZERO # the kick took its direction; no thrust after
	await physics_frames(frame_count(0.15) + 2) # past ZeroGMode.KICK_GRACE
	assert_true(p.grabbed, "the same wall catches again once the grace period ends")
	assert_true(p.grab_normal.is_equal_approx(Vector2.LEFT), "same wall, got %s" % p.grab_normal)

func test_thrust_builds_to_its_cap_and_no_further() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(-800, 0))
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.25))
	assert_true(absf(p.velocity.x - Player.THRUST_ACCEL * 0.25) < 15.0, "a quarter second of thrust, got %f" % p.velocity.x)
	await physics_frames(frame_count(1.5))
	assert_true(absf(p.velocity.x - Player.THRUST_MAX) < 1.0, "capped at thrust speed, got %f" % p.velocity.x)

func test_thrust_does_not_slow_a_faster_body() -> void:
	var r := make_room(false, Vector2(4000, 1200))
	var p := spawn_player(Vector2(-1500, 0))
	p.velocity = Vector2(500, 0) # faster than thrust can go: a kick, a vent, a ricochet
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(10)
	assert_true(absf(p.velocity.x - 500.0) < 0.01, "no cap applied to speed the stick did not give, got %f" % p.velocity.x)
