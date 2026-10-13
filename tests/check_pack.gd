extends SceneTree

## Checks an exported pack before it is published:
##   godot --headless --main-pack build/web/index.pck -s tests/check_pack.gd
## Every room must load from the pack with its full bounds: its exits'
## arrival points and its airlock's spawn point inside them, and at least one
## screen cell in size. An export once shrank every room to the Compartment
## scene's default bounds (a text-to-binary conversion dropped the override),
## which left the Dock's airlock outside its compartment and the start in zero-g.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures := 0
	for name in WorldGraph.ROOMS:
		var path := Game.scene_path(name)
		if not ResourceLoader.exists(path):
			print("  FAIL  %s: no scene in the pack" % name)
			failures += 1
			continue
		var r: Room = load(path).instantiate()
		root.add_child(r)
		var b := r.bounds()
		var ok := b.size.x >= 1152.0 and b.size.y >= 648.0
		for e in r.exits():
			ok = ok and b.has_point(e.arrival_point())
		if r.checkpoint() != null:
			ok = ok and b.has_point(r.checkpoint().spawn_point())
		print("  %s  %s bounds=%s" % ["ok  " if ok else "FAIL", name, b.size])
		if not ok:
			failures += 1
		root.remove_child(r)
		r.free()
	# The section: both sides of every edge must meet at the same seam in the
	# pack too, since the export's resource conversion has dropped scene
	# overrides before.
	var s := Section.new()
	root.add_child(s)
	var seams_ok := true
	for e in WorldGraph.EDGES:
		var a: Exit = s.room(e[0]).exit_named(e[1])
		var b: Exit = s.room(e[2]).exit_named(e[3])
		var sa := a.global_position - a.inward * 16.0
		var sb := b.global_position - b.inward * 16.0
		if sa.distance_to(sb) > 1.0:
			print("  FAIL  %s %s meets %s %s: %s vs %s" % [e[0], e[1], e[2], e[3], sa, sb])
			seams_ok = false
	if seams_ok:
		print("  ok    section: every doorway meets its neighbour")
	else:
		failures += 1
	root.remove_child(s)
	s.free()
	print("%d rooms, %d failed" % [WorldGraph.ROOMS.size(), failures])
	quit(1 if failures > 0 else 0)
