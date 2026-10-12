extends TestCase

func test_every_room_in_the_graph_has_a_scene_with_the_declared_exits_and_plates() -> void:
	for name in WorldGraph.ROOMS:
		var path := Game.scene_path(name)
		assert_true(ResourceLoader.exists(path), "%s has a scene" % name)
		if not ResourceLoader.exists(path):
			continue
		var r: Room = add(load(path).instantiate())
		assert_eq(r.room_name, name, "scene names itself")
		assert_eq(r.compartment.plates_live, WorldGraph.ROOMS[name].plates_live, "%s plates" % name)
		var declared := WorldGraph.exits_of(name)
		var built := r.exits().map(func(e): return e.exit_name)
		declared.sort()
		built.sort()
		assert_eq(built, Array(declared), "%s exits match the graph" % name)
		assert_eq(r.checkpoint() != null, WorldGraph.ROOMS[name].checkpoint, "%s checkpoint" % name)
		var panels := r.find_children("*", "Switch", true, false).map(func(s): return s.switch_name)
		for panel in WorldGraph.ROOMS[name].panels:
			if panel != "boss":
				assert_true(panels.has(panel), "%s has the %s panel" % [name, panel])
		r.free()

func test_every_exit_points_into_its_room() -> void:
	for name in WorldGraph.ROOMS:
		var r: Room = add(load(Game.scene_path(name)).instantiate())
		await physics_frames(1)
		for e in r.exits():
			assert_true(r.bounds().has_point(e.arrival_point()), "%s %s arrives inside the room" % [name, e.exit_name])
		r.free()
