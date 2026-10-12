extends TestCase

func _clinger(at: Vector2) -> Clinger:
	var c: Clinger = load("res://scenes/Clinger.tscn").instantiate()
	c.position = at
	return add(c) as Clinger

func _shots() -> Array:
	return tree.root.get_children().filter(func(n): return n is Shot and not n.from_player)

func test_fixed_in_gravity_and_shoots_on_a_period() -> void:
	var r := make_room(true)
	var c := _clinger(Vector2(0, r.floor_y - 16))
	var p := spawn_player(Vector2(300, r.floor_y - 30))
	await physics_frames(frame_count(Clinger.PERIOD * 2.5))
	assert_true(absf(c.global_position.x) < 1.0, "has not moved")
	assert_true(p.health <= 4, "the player has been shot")
	assert_true(_shots().size() <= 1, "one slow shot at a time, about")

func test_becomes_debris_in_zero_g_and_rides_the_vent() -> void:
	var r := make_room(false)
	var v: Vent = load("res://scenes/Vent.tscn").instantiate()
	(v.get_node("Bounds") as CollisionShape2D).shape.size = Vector2(1800, 1000)
	add(v)
	var c := _clinger(Vector2(-500, 0))
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(c.velocity.x > Vent.FORCE_ZERO_G * 0.4, "pushed, got %f" % c.velocity.x)

func test_keeps_shooting_while_drifting() -> void:
	var r := make_room(false)
	var c := _clinger(Vector2(-300, 0))
	c.velocity = Vector2(50, 0)
	var p := spawn_player(Vector2(200, 0))
	await physics_frames(frame_count(Clinger.PERIOD + 0.2))
	assert_true(_shots().size() >= 1 or p.health < Player.MAX_HEALTH, "shot while moving")
