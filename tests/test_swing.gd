extends TestCase

func _block(at: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 2
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	s.shape.size = Vector2(60, 60)
	b.add_child(s)
	b.position = at
	b.add_to_group(Groups.HITTABLE)
	b.add_to_group(Groups.BOUNCY)
	return add(b) as StaticBody2D

func test_swing_flips_a_switch_and_cannot_be_spammed() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.switch_name = "vents"
	s.position = Vector2(Swing.REACH, r.floor_y - 30)
	p.input_override.swing_pressed = true
	await physics_frames(frame_count(Swing.ACTIVE + Swing.RECOVERY) - 2)
	assert_true(WorldState.vents_open, "one swing, one flip")
	assert_true(p.swing.is_busy(), "still recovering")
	await physics_frames(frame_count(Switch.REHIT_DELAY) + 4)
	assert_true(not WorldState.vents_open, "the next swing flips it back")

func test_down_swing_in_the_air_pogos() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 200))
	_block(Vector2(0, r.floor_y - 200 + Swing.REACH + 20))
	p.input_override.aim = Vector2.DOWN
	p.input_override.swing_pressed = true
	await physics_frames(2)
	assert_true(p.velocity.y <= -Player.JUMP_SPEED + 50.0, "bounced up near jump speed (one frame of gravity allowed), got %f" % p.velocity.y)

func test_down_on_the_floor_swings_forward() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(frame_count(0.25)) # the spawn is a few px up; let it land
	p.input_override.aim = Vector2.DOWN
	assert_eq(p.aim_for_swing(p.input_override), Vector2.RIGHT, "forward, not into the floor")

func test_ricochet_in_zero_g_rebounds_in_any_direction() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	var dir := Vector2(1, 1).normalized()
	_block(dir * (Swing.REACH + 20))
	p.input_override.aim = dir
	p.input_override.swing_pressed = true
	await physics_frames(2)
	assert_true(p.velocity.is_equal_approx(-dir * Player.KICK_SPEED), "rebounds opposite the swing, got %s" % p.velocity)

func test_pogo_rises_like_a_jump_without_holding_jump() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 200))
	_block(Vector2(0, r.floor_y - 200 + Swing.REACH + 20))
	p.input_override.aim = Vector2.DOWN
	p.input_override.swing_pressed = true
	await physics_frames(2)
	p.input_override.swing_pressed = false
	p.input_override.aim = Vector2.ZERO
	var start_y := p.global_position.y
	var top := start_y
	for i in range(frame_count(1.0)):
		await physics_frames(1)
		top = minf(top, p.global_position.y)
	assert_true(start_y - top > 80.0, "a pogo rises over 80 px with jump released, got %f" % (start_y - top))

func test_a_switch_does_not_bounce_the_swing() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.position = Vector2(Swing.REACH + 10, 0)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.swing_pressed = true
	await physics_frames(2)
	assert_true(not WorldState.ring_on, "the panel was hit")
	assert_true(p.velocity.x > -1.0 and p.velocity.x < 60.0, "no ricochet off a panel, only the stick's own thrust, got %s" % p.velocity)
