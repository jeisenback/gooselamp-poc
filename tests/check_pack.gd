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
	print("%d rooms, %d failed" % [WorldGraph.ROOMS.size(), failures])
	quit(1 if failures > 0 else 0)
