class_name Respawner extends Node

## The death flow, until the game controller owns it: when the player dies,
## wait, find the airlock they last rested at (or the first airlock there
## is), respawn the enemies and put the player back at its foot. World
## state is untouched: dying does not reset switches.

var _player: Player = null
var _lookup: Callable        # lookup(room_name) -> Checkpoint or null

func bind(player: Player, checkpoint_lookup: Callable) -> void:
	_player = player
	_lookup = checkpoint_lookup
	player.died.connect(_on_died)

func _on_died() -> void:
	await get_tree().create_timer(Player.DEATH_DELAY, true, true).timeout
	if not is_instance_valid(_player):
		return
	var checkpoint: Checkpoint = _lookup.call(WorldState.checkpoint) if _lookup.is_valid() else null
	if checkpoint == null:
		checkpoint = get_tree().get_first_node_in_group(Groups.CHECKPOINT)
	Spawner.respawn_all(get_tree())
	_player.respawn(checkpoint.spawn_point() if checkpoint != null else _player.global_position)
