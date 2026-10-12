class_name Checkpoint extends StaticBody2D

## An airlock. A player swinging at it rests: full health, the checkpoint
## and a save, every spawner respawns. Dying returns the player here.

@export var room_name: String = ""

signal rested

func _ready() -> void:
	add_to_group(Groups.HITTABLE)
	add_to_group(Groups.CHECKPOINT)

## The swing. Only a player rests.
func hit(from: Node2D, _direction: Vector2) -> void:
	if from is Player:
		rest(from)

func rest(player: Player) -> void:
	player.heal_full()
	WorldState.set_checkpoint(room_name)
	WorldState.save()
	Spawner.respawn_all(get_tree())
	Sfx.play("hatch")
	rested.emit()

## Where the player stands after a rest or a death: the Spawn marker at its foot.
func spawn_point() -> Vector2:
	var spawn := get_node_or_null("Spawn") as Node2D
	return spawn.global_position if spawn != null else global_position
