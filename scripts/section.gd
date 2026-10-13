class_name Section extends Node2D

## The Hulk's section as one scene: every room in WorldGraph.ROOMS instanced
## at its grid offset, over a backdrop in the hull colour so a look past a
## door into a narrower neighbour shows ship structure, not the clear colour.
## Rooms keep their own scenes; this only places them. Node names are the
## room names without spaces, as Game.scene_path spells them.

const CELL := Vector2(1152, 648)
const LOOKAHEAD := 384.0                   # how far the camera may look past a door, one third of a screen
const HULL := Color(0.1, 0.11, 0.13)       # tools/build_rooms.py HULL

func _ready() -> void:
	var all := Rect2()
	var first := true
	for name in WorldGraph.ROOMS:
		var g: Rect2i = WorldGraph.ROOMS[name].grid
		var cells := Rect2(Vector2(g.position) * CELL, Vector2(g.size) * CELL)
		all = cells if first else all.merge(cells)
		first = false
	var back := Polygon2D.new()
	back.name = "Backdrop"
	back.color = HULL
	var b := all.grow(LOOKAHEAD)
	back.polygon = PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)])
	add_child(back)
	for name in WorldGraph.ROOMS:
		var r: Room = load(Game.scene_path(name)).instantiate()
		r.name = name.replace(" ", "")
		r.position = Vector2(WorldGraph.ROOMS[name].grid.position) * CELL
		add_child(r)

func room(room_name: String) -> Room:
	return get_node_or_null(room_name.replace(" ", "")) as Room

func rooms() -> Array[Room]:
	var out: Array[Room] = []
	for c in get_children():
		if c is Room:
			out.append(c)
	return out
