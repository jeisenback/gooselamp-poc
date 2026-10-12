class_name Room extends Node2D

## One room scene: a Compartment covering it, a Hull, an Exits node of Exit
## areas, and whatever lives there. Rooms sit at the origin and are one or
## more screen cells in size.

@export var room_name: String = ""
@export var floor_y: float = 0.0           # the main floor's top surface, in room coordinates

@onready var compartment: Compartment = $Compartment

## World rect of the compartment's Bounds shape.
func bounds() -> Rect2:
	var shape := compartment.get_node("Bounds") as CollisionShape2D
	var size: Vector2 = shape.shape.size
	return Rect2(compartment.global_position - size / 2.0, size)

## Children of $Exits.
func exits() -> Array[Exit]:
	var out: Array[Exit] = []
	var holder := get_node_or_null("Exits")
	if holder != null:
		for c in holder.get_children():
			if c is Exit:
				out.append(c)
	return out

func exit_named(n: String) -> Exit:
	for e in exits():
		if e.exit_name == n:
			return e
	return null

## The first Checkpoint in the room, or null.
func checkpoint() -> Checkpoint:
	var found := find_children("*", "Checkpoint", true, false)
	return found[0] if not found.is_empty() else null
