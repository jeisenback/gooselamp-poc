class_name Porthole extends Node2D

## A window onto another room: a second camera, in a SubViewport that shares
## the main world, drawn on a quad in the wall. The Locker's looks into the
## Control Room, so the Warden seen is the one fought. Without a Section
## above it (a room loaded alone) there is nothing to aim at and the glass
## stays dark.

const SIZE := Vector2i(200, 140)
const ZOOM := 0.175      # the whole room in the glass: 200 px for its 1152, so the Warden can be watched wherever it is

@export var target_room: String = "Control Room"

func _ready() -> void:
	$SubViewport.world_2d = get_viewport().world_2d
	$Glass.texture = $SubViewport.get_texture()
	aim.call_deferred() # the target room is added to the section after this one

## Points the camera at the target room's centre. False when no Section
## above holds that room.
func aim() -> bool:
	var node := get_parent()
	while node != null and not node is Section:
		node = node.get_parent()
	if node == null:
		return false
	var r: Room = (node as Section).room(target_room)
	if r == null:
		return false
	$SubViewport/Camera2D.global_position = r.bounds().get_center()
	return true
