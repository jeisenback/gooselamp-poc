class_name CompartmentTracker extends RefCounted

## Which compartments a body overlaps, last entered last. Shared by the
## player and the enemies: the last one entered decides gravity, and none
## at all is space, which is zero-g.

var compartments: Array[Compartment] = []

func enter(c: Compartment) -> void:
	compartments.erase(c)
	compartments.append(c)

func exit(c: Compartment) -> void:
	compartments.erase(c)

func zero_g() -> bool:
	return compartments.is_empty() or not compartments[-1].has_gravity()
