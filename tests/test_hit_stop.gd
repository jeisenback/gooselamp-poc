extends TestCase

func test_a_landed_swing_freezes_both_for_three_frames() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(Swing.REACH + 10, 0)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(0, 50)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.swing_pressed = true
	await physics_frames(3) # the swing starts, is seen overlapping the enemy a tick later than a static body, lands
	p.input_override.swing_pressed = false
	var frozen_at := p.global_position
	await physics_frames(HitStop.FRAMES - 1)
	assert_eq(p.global_position, frozen_at, "the player holds still")
	assert_eq(p.process_mode, Node.PROCESS_MODE_DISABLED, "frozen")
	await physics_frames(3)
	assert_eq(p.process_mode, Node.PROCESS_MODE_INHERIT, "thawed")
	assert_true(p.global_position != frozen_at, "moving again")

func test_killing_with_the_freezing_swing_is_not_an_error() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(Swing.REACH + 10, 0)
	e.health = 1
	var p := spawn_player(Vector2.ZERO)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.swing_pressed = true
	await physics_frames(HitStop.FRAMES + 4)
	assert_true(not is_instance_valid(e), "dead")
	assert_eq(p.process_mode, Node.PROCESS_MODE_INHERIT, "player thawed with no error on the freed enemy")
