class_name Exit extends Area2D

## A doorway out of a room. Emits `crossed` every physics frame a Player
## overlaps it; the Game decides whether to swap rooms. Only a Player body
## counts: enemies and shots drifting through do nothing.

const ARRIVAL_OFFSET := 48.0

@export var exit_name: String = ""
@export var inward: Vector2 = Vector2.RIGHT # unit vector pointing into the room

signal crossed(exit: Exit)

func _ready() -> void:
	inward = inward.normalized()

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			crossed.emit(self)
			return

## Where a player arriving through this exit is placed: just inside the room.
func arrival_point() -> Vector2:
	return global_position + inward * ARRIVAL_OFFSET
