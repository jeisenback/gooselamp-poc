extends TestCase

func test_a_player_shot_chips_and_staggers_an_enemy_then_dies() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(200, 0)
	var p := spawn_player(Vector2.ZERO)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(1)
	p.input_override.fire_pressed = false
	var shot := tree.root.get_children().filter(func(n): return n is Shot)
	assert_eq(shot.size(), 1, "one shot in flight")
	await physics_frames(frame_count(0.4))
	assert_eq(e.health, 2, "chipped")
	assert_true(e.staggered_for > 0.0, "staggered")
	assert_true(tree.root.get_children().filter(func(n): return n is Shot).is_empty(), "shot gone")

func test_a_shot_dies_on_a_wall_and_never_hits_its_shooter() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(980, 0))   # against the right wall
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(3)
	assert_eq(p.health, Player.MAX_HEALTH, "did not shoot itself")
	assert_true(tree.root.get_children().filter(func(n): return n is Shot).is_empty(), "freed on the wall")

func test_a_shot_expires() -> void:
	var r := make_room(false, Vector2(4000, 1200))
	var s := Shot.spawn(tree.root, null, Vector2.ZERO, Vector2.RIGHT, true)
	await physics_frames(frame_count(Shot.LIFETIME) + 2)
	assert_true(not is_instance_valid(s), "gone after its lifetime")

func test_an_enemy_shot_hurts_the_player() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	Shot.spawn(tree.root, null, Vector2(-100, 0), Vector2.RIGHT, false)
	await physics_frames(frame_count(1.0))
	assert_eq(p.health, 4, "hit by the slow shot")
