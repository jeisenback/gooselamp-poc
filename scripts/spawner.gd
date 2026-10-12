class_name Spawner extends Marker2D

## Where an enemy lives. Spawns its scene on ready and again on every rest,
## freeing the old one; the only way enemies enter a room.

@export var scene: PackedScene

var spawned: Node = null

func _ready() -> void:
	add_to_group(Groups.SPAWNER)
	spawn()

## Frees the old, instantiates the new as a child at the marker.
func spawn() -> void:
	if is_instance_valid(spawned):
		spawned.queue_free()
	spawned = null
	if scene == null:
		return
	spawned = scene.instantiate()
	add_child(spawned)

## spawn() on every member of Groups.SPAWNER.
static func respawn_all(tree: SceneTree) -> void:
	for s in tree.get_nodes_in_group(Groups.SPAWNER):
		s.spawn()
