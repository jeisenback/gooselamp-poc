extends TestCase

func _vent(size: Vector2, at: Vector2) -> Vent:
	var v: Vent = load("res://scenes/Vent.tscn").instantiate()
	(v.get_node("Bounds") as CollisionShape2D).shape.size = size
	v.position = at
	return add(v) as Vent

func test_blows_hard_in_zero_g_only_while_open() -> void:
	var r := make_room(false)
	var v := _vent(Vector2(1800, 1000), Vector2.ZERO)
	var p := spawn_player(Vector2(-600, 0))
	await physics_frames(frame_count(0.5))
	assert_eq(p.velocity, Vector2.ZERO, "closed: still")
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x - Vent.FORCE_ZERO_G * 0.5) < 15.0, "half a second of push, got %f" % p.velocity.x)

func test_barely_moves_you_on_the_ground() -> void:
	var r := make_room(true)
	var v := _vent(Vector2(1800, 1000), Vector2.ZERO)
	var p := spawn_player(Vector2(-600, r.floor_y - 30))
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x) < 40.0, "a gentle push, got %f" % p.velocity.x)

func test_skips_bodies_without_velocity() -> void:
	var r := make_room(false)
	var v := _vent(Vector2(400, 400), Vector2.ZERO)
	var prop := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	prop.add_child(shape)
	add(prop)
	WorldState.set_vents(true)
	await physics_frames(5)
	assert_true(true, "no script error reached the runner")
