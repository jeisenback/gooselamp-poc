extends TestCase

func _section() -> Section:
	return add(Section.new()) as Section

func test_every_room_is_a_child_at_its_grid_offset() -> void:
	var s := _section()
	for name in WorldGraph.ROOMS:
		var r := s.room(name)
		assert_true(r != null, "%s is in the section" % name)
		if r == null:
			continue
		var want := Vector2(WorldGraph.ROOMS[name].grid.position) * Section.CELL
		assert_true(r.global_position.is_equal_approx(want), "%s at %s, want %s" % [name, r.global_position, want])
	assert_eq(s.rooms().size(), WorldGraph.ROOMS.size(), "all of them, nothing else")

func test_rooms_touch_but_never_overlap() -> void:
	var s := _section()
	var rooms := s.rooms()
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a := rooms[i].bounds()
			var b := rooms[j].bounds()
			assert_true(not a.intersects(b, false), "%s and %s overlap" % [rooms[i].room_name, rooms[j].room_name])

func test_the_hull_between_two_rooms_belongs_to_both() -> void:
	var s := _section()
	var dock := s.room("Dock")
	var spine := s.room("Spine West")
	var seam := Vector2(dock.bounds().end.x, dock.exit_named("east").global_position.y)
	assert_true(dock.bounds().has_point(seam - Vector2(1, 0)) and spine.bounds().has_point(seam + Vector2(1, 0)), "no gap at the seam")
	assert_true(dock.bounds().has_point(dock.exit_named("east").global_position), "the exit's hull is inside the room")

func test_backdrop_covers_every_room_and_the_lookahead() -> void:
	var s := _section()
	var back := s.get_node("Backdrop") as Polygon2D
	assert_true(back != null and s.get_child(0) == back, "first child, drawn under the rooms")
	var all := Rect2()
	for r in s.rooms():
		all = r.bounds() if all.size == Vector2.ZERO else all.merge(r.bounds())
	var want := all.grow(Section.LOOKAHEAD)
	var got := Rect2(back.polygon[0], back.polygon[2] - back.polygon[0])
	assert_true(got.encloses(want), "backdrop %s encloses %s" % [got, want])
