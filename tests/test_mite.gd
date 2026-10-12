extends TestCase

## A free-floating 200 by 100 block in a zero-g room; the mite starts on its top.
func _block_and_mite() -> Array:
	var r := make_room(false)
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(200, 100)
	block.add_child(shape)
	add(block)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(0, -50 - Mite.RADIUS)
	add(m)
	return [block, m]

func test_crawls_round_every_face_of_a_block_and_never_leaves_it() -> void:
	var pair := _block_and_mite()
	var m: Mite = pair[1]
	var normals_seen := {}
	for i in range(frame_count(12.0)):
		await physics_frames(1)
		normals_seen[m.normal.round()] = true
		var inside := Rect2(Vector2(-100, -50), Vector2(200, 100)).grow(20.0)
		assert_true(inside.has_point(m.global_position), "left the block at frame %d: %s" % [i, m.global_position])
		if normals_seen.size() == 4:
			break
	assert_eq(normals_seen.size(), 4, "visited all four faces: %s" % [normals_seen.keys()])

func test_turns_at_a_concave_corner() -> void:
	var r := make_room(true)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(950, r.floor_y - Mite.RADIUS)
	add(m)
	await physics_frames(frame_count(2.0))
	assert_true(m.normal.is_equal_approx(Vector2.LEFT), "now on the right wall, got %s" % m.normal)
	assert_true(m.global_position.y < r.floor_y - 40, "climbing it")

func test_ignores_gravity() -> void:
	var r := make_room(true)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(0, r.floor_y - 300)
	m.normal = Vector2.DOWN   # standing on a ceiling that is not there
	add(m)
	await physics_frames(10)
	assert_true(m.global_position.y < r.floor_y - 200, "did not fall")
