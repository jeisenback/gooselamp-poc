class_name Compartment extends Area2D

## One per room. Declares live or dead plates and shows or hides the children
## that belong to a world state: direct children named RingOn, RingOff,
## VentsOpen and VentsClosed are active only while their state holds. Bodies
## that enter are told `enter_compartment(self)`, bodies that leave
## `exit_compartment(self)`, so a body can ask `has_gravity()`.

const STATE_CHILDREN := ["RingOn", "RingOff", "VentsOpen", "VentsClosed"]

@export var plates_live: bool = true
@export var room_name: String = ""

var _seen_version: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	apply()

func _physics_process(_delta: float) -> void:
	if WorldState.version != _seen_version:
		apply()

## Dead plates are zero-g whatever the ring does.
func has_gravity() -> bool:
	return plates_live and WorldState.ring_on

## Show and hide the state children for the state as it is now.
func apply() -> void:
	_seen_version = WorldState.version
	_set_active("RingOn", WorldState.ring_on)
	_set_active("RingOff", not WorldState.ring_on)
	_set_active("VentsOpen", WorldState.vents_open)
	_set_active("VentsClosed", not WorldState.vents_open)

func _set_active(child_name: String, active: bool) -> void:
	var child := get_node_or_null(child_name)
	if child == null:
		return
	if child is CanvasItem:
		child.visible = active
	child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collision(child, not active)

func _set_collision(node: Node, disabled: bool) -> void:
	for c in node.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.disabled = disabled
		_set_collision(c, disabled)

func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_compartment"):
		body.enter_compartment(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_compartment"):
		body.exit_compartment(self)
