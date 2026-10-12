extends TestCase

## Nodes are [room, ring_on, vents_open, boss_down]. From a node you may cross any edge whose needs hold,
## or flip a panel in the room ("boss" only turns boss_down on, once; it never turns off).
func _neighbours(node: Array) -> Array:
	var out := []
	var state := {"ring_on": node[1], "vents_open": node[2], "boss_down": node[3]}
	for e in WorldGraph.EDGES:
		if e[0] == node[0] and WorldGraph.allows(e[4], state):
			out.append([e[2], node[1], node[2], node[3]])
	for panel in WorldGraph.ROOMS[node[0]].panels:
		match panel:
			"ring": out.append([node[0], not node[1], node[2], node[3]])
			"vents": out.append([node[0], node[1], not node[2], node[3]])
			"boss": if not node[3]: out.append([node[0], node[1], node[2], true])
	return out

func _reachable_from(start: Array) -> Dictionary:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var n = queue.pop_front()
		for m in _neighbours(n):
			if not seen.has(m):
				seen[m] = true
				queue.append(m)
	return seen

func test_no_reachable_dead_end() -> void:
	var start := [WorldGraph.START, true, false, false]
	var reachable := _reachable_from(start)
	assert_true(reachable.size() > 13, "the product graph is explored (%d nodes)" % reachable.size())
	for node in reachable:
		var onward := _reachable_from(node)
		var ends := onward.keys().filter(func(n): return n[0] == WorldGraph.END)
		assert_true(not ends.is_empty(), "dead end: in %s with ring_on=%s vents_open=%s boss_down=%s the Exit is unreachable" % node)

func test_the_designed_path_is_walkable_with_the_designed_flips() -> void:
	var state := {"ring_on": true, "vents_open": false, "boss_down": false}
	var flips := {"Blister": "ring", "Vent Room": "vents", "Control Room": "boss"}
	var path := WorldGraph.REQUIRED_PATH
	for i in range(path.size() - 1):
		var here: String = path[i]
		if flips.has(here):
			match flips[here]:
				"ring": state.ring_on = not state.ring_on
				"vents": state.vents_open = not state.vents_open
				"boss": state.boss_down = true
			flips.erase(here)
		var edges := WorldGraph.EDGES.filter(func(e): return e[0] == here and e[2] == path[i + 1])
		assert_true(not edges.is_empty(), "an edge from %s to %s exists" % [here, path[i + 1]])
		assert_true(edges.any(func(e): return WorldGraph.allows(e[4], state)), "%s to %s is open at step %d" % [here, path[i + 1], i])

func test_the_locker_is_reachable_and_needs_both_switches() -> void:
	var reachable := _reachable_from([WorldGraph.START, true, false, false])
	var in_locker := reachable.keys().filter(func(n): return n[0] == "Locker")
	assert_true(not in_locker.is_empty(), "the secret can be reached")
	for n in in_locker:
		assert_true(not n[1] and not n[2], "only with ring off and vents closed: %s" % [n])

func test_every_edge_has_a_return_and_names_real_rooms_and_exits() -> void:
	for e in WorldGraph.EDGES:
		assert_true(WorldGraph.ROOMS.has(e[0]) and WorldGraph.ROOMS.has(e[2]), "%s names real rooms" % [e])
		var back := WorldGraph.EDGES.filter(func(b): return b[0] == e[2] and b[1] == e[3] and b[2] == e[0] and b[3] == e[1])
		assert_eq(back.size(), 1, "%s has exactly one return edge" % [e])
		for need in e[4]:
			assert_true(need in ["ring_on", "ring_off", "vents_open", "vents_closed", "boss_down"], "known predicate %s" % need)

func test_rooms_do_not_overlap_on_the_map() -> void:
	var names := WorldGraph.ROOMS.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var a: Rect2i = WorldGraph.ROOMS[names[i]].grid
			var b: Rect2i = WorldGraph.ROOMS[names[j]].grid
			assert_true(not a.intersects(b), "%s and %s overlap" % [names[i], names[j]])
