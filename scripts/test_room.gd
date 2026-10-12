class_name TestRoom extends Node2D

## A playable test scene: compartments, a player, a camera that never
## rotates, the HUD and the death flow. Tints each compartment by whether it
## has gravity. The main scene is the test room; `--arena` (or `?arena` on
## the web) opens the Warden's arena instead.

const ARENA := "res://scenes/TestArena.tscn"
const TINT_GRAVITY := Color(1.0, 0.72, 0.4, 0.10)   # warm
const TINT_ZERO_G := Color(0.4, 0.7, 1.0, 0.12)     # cool

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	if LaunchOptions.has("arena") and scene_file_path != ARENA:
		get_tree().change_scene_to_file.call_deferred(ARENA)
		return
	camera.global_position = player.global_position
	camera.reset_smoothing()
	var hud := get_node_or_null("HUD") as Hud
	if hud != null:
		hud.bind(player)
	var respawner := get_node_or_null("Respawner") as Respawner
	if respawner != null:
		respawner.bind(player, _checkpoint_named)

func _checkpoint_named(room_name: String) -> Checkpoint:
	for c in get_tree().get_nodes_in_group(Groups.CHECKPOINT):
		if c.room_name == room_name:
			return c
	return null

func _process(_delta: float) -> void:
	camera.global_position = player.global_position
	for compartment in find_children("*", "Compartment", false, false):
		var tint := compartment.get_node_or_null("Tint") as Polygon2D
		if tint != null:
			tint.color = TINT_GRAVITY if compartment.has_gravity() else TINT_ZERO_G
