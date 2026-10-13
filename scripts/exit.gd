class_name Exit extends Area2D

## A doorway out of a room: where a player placed through it arrives, and
## the point the graph's backstop sets a leaked body back to. The area sits
## in the hull and reaches outward, never past the hull's inner face.

const ARRIVAL_OFFSET := 48.0

@export var exit_name: String = ""
@export var inward: Vector2 = Vector2.RIGHT # unit vector pointing into the room

func _ready() -> void:
	inward = inward.normalized()
	$CollisionShape2D.position = -inward.rotated(-rotation) * 16.0 # the 64 px area spans the hull and 32 px outward

## Where a player arriving through this exit is placed: just inside the room.
func arrival_point() -> Vector2:
	return global_position + inward * ARRIVAL_OFFSET
