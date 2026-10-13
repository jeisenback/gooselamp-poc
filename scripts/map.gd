class_name Map extends CanvasLayer

## The map: one box per visited room from WorldGraph's grid, the current
## room filled bright, a mark for each panel in a visited room, and the
## player's dot. Opens on the `map` action, while paused and while dead too.

const CELL := 24.0                         # px per grid cell on screen
const SCREEN := Vector2(1152, 648)
const BOX := Color(0.3, 0.33, 0.4)
const CURRENT := Color(0.85, 0.9, 1.0)
const PANEL := Color(0.95, 0.85, 0.35)
const DOT := Color(1.0, 0.4, 0.25)
const SHADE := Color(0.02, 0.02, 0.03, 0.85)

var _current: String = ""
var _canvas: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("map"):
		toggle()
	if visible:
		_canvas.queue_redraw()

func toggle() -> void:
	visible = not visible
	_canvas.queue_redraw()

func set_current(room_name: String) -> void:
	_current = room_name
	_canvas.queue_redraw()

## Visited rooms drawn.
func boxes_drawn() -> int:
	return _visited().size()

## Panels in visited rooms.
func panels_marked() -> int:
	var count := 0
	for name in _visited():
		for panel in WorldGraph.ROOMS[name].panels:
			if panel != "boss":
				count += 1
	return count

func _visited() -> Array:
	var out := []
	for name in WorldState.visited:
		if WorldGraph.ROOMS.has(name):
			out.append(name)
	return out

## Screen offset that centres the whole graph.
func _origin() -> Vector2:
	var all := Rect2i()
	var first := true
	for name in WorldGraph.ROOMS:
		var g: Rect2i = WorldGraph.ROOMS[name].grid
		all = g if first else all.merge(g)
		first = false
	var size := Vector2(all.size) * CELL
	return SCREEN / 2.0 - size / 2.0 - Vector2(all.position) * CELL

func _box(name: String) -> Rect2:
	var g: Rect2i = WorldGraph.ROOMS[name].grid
	return Rect2(_origin() + Vector2(g.position) * CELL, Vector2(g.size) * CELL)

func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), SHADE)
	for name in _visited():
		var box := _box(name)
		_canvas.draw_rect(box.grow(-2.0), CURRENT if name == _current else BOX)
		var i := 0
		for panel in WorldGraph.ROOMS[name].panels:
			if panel == "boss":
				continue
			_canvas.draw_rect(Rect2(box.position + Vector2(4 + i * 7, 4), Vector2(5, 5)), PANEL)
			i += 1
	var game := get_parent() as Game
	if game != null and game.current != null and WorldGraph.ROOMS.has(game.current.room_name):
		var box := _box(game.current.room_name)
		var b := game.current.bounds()
		var t := (game.player.global_position - b.position) / b.size
		var dot := box.position + Vector2(clampf(t.x, 0.0, 1.0), clampf(t.y, 0.0, 1.0)) * box.size
		_canvas.draw_circle(dot, 3.0, DOT)
