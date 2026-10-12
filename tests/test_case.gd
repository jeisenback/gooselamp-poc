extends RefCounted
class_name TestCase

## Base for test scripts run by tests/run_tests.gd. GDScript has no
## exceptions, so assertions record failures instead of aborting; the
## runner reports them per test. `tree` is set before each test so
## scene tests can add nodes and await frames.

const TEST_SAVE_PATH := "user://test_save.cfg"

var tree: SceneTree
var failures: Array[String] = []

func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append(message if message != "" else "expected true")

## Nodes added here are freed after the test.
func add(node: Node) -> Node:
	tree.root.add_child(node)
	return node

func physics_frames(count: int) -> void:
	for i in range(count):
		await tree.physics_frame

## ceil(seconds * 60)
func frame_count(seconds: float) -> int:
	return ceili(seconds * 60.0)

## A closed box of static walls (thickness 32) with a Compartment covering it.
## Keys: "room", "compartment", "floor_y". `size` is the inside of the box and
## `origin` its centre; `floor_y` is the floor's top surface in world space.
## Tests remove named walls (Walls/Floor, Walls/Ceiling, Walls/Left, Walls/Right) to join rooms.
func make_room(plates_live: bool, size: Vector2 = Vector2(2000, 1200), origin: Vector2 = Vector2.ZERO) -> Dictionary:
	const T := 32.0
	var room := Node2D.new()
	room.name = "Room"
	room.position = origin
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	var half := size / 2.0
	var specs := {
		"Floor": [Vector2(0, half.y + T / 2.0), Vector2(size.x + 2.0 * T, T)],
		"Ceiling": [Vector2(0, -half.y - T / 2.0), Vector2(size.x + 2.0 * T, T)],
		"Left": [Vector2(-half.x - T / 2.0, 0), Vector2(T, size.y + 2.0 * T)],
		"Right": [Vector2(half.x + T / 2.0, 0), Vector2(T, size.y + 2.0 * T)],
	}
	for wall_name in specs:
		var shape := CollisionShape2D.new()
		shape.name = wall_name
		shape.shape = RectangleShape2D.new()
		shape.shape.size = specs[wall_name][1]
		shape.position = specs[wall_name][0]
		walls.add_child(shape)
	room.add_child(walls)
	var compartment: Compartment = load("res://scenes/Compartment.tscn").instantiate()
	compartment.name = "Compartment"
	compartment.plates_live = plates_live
	(compartment.get_node("Bounds") as CollisionShape2D).shape.size = size
	room.add_child(compartment)
	add(room)
	return {"room": room, "compartment": compartment, "floor_y": origin.y + half.y}

## Adds Player.tscn at `at` with an empty input_override, so no real input reaches it.
func spawn_player(at: Vector2) -> Player:
	var p: Player = load("res://scenes/Player.tscn").instantiate()
	p.input_override = PlayerInput.new()
	p.global_position = at
	add(p)
	return p
