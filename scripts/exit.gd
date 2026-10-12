class_name Exit extends Area2D

## A doorway out of a room. Emits `crossed` every physics frame a Player
## overlaps it; the Game decides whether to swap rooms. Only a Player body
## counts: enemies and shots drifting through do nothing. The area sits in
## the hull and reaches outward, never past the hull's inner face, so a
## player pressed against a shut door (which stands proud of that face) is
## not in it.

const ARRIVAL_OFFSET := 48.0

@export var exit_name: String = ""
@export var inward: Vector2 = Vector2.RIGHT # unit vector pointing into the room

signal crossed(exit: Exit)

func _ready() -> void:
	inward = inward.normalized()
	$CollisionShape2D.position = -inward.rotated(-rotation) * 16.0 # the 64 px area spans the hull and 32 px outward

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			crossed.emit(self)
			return

## Where a player arriving through this exit is placed: just inside the room.
func arrival_point() -> Vector2:
	return global_position + inward * ARRIVAL_OFFSET
