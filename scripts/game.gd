class_name Game extends Node2D

## The game: one Room at a time, swapped when the player crosses an Exit,
## with velocity preserved across the swap. Owns the player, the camera, the
## HUD, the title and the death flow.

const SWAP_COOLDOWN := 0.3                 # seconds after a swap during which exits are ignored
const ROOMS_DIR := "res://scenes/rooms/"

var room: Room = null
var player: Player
var _cooldown: float = 0.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	player = $Player
	$HUD.bind(player)
	$Respawner.bind(player, _checkpoint_for)
	if get_tree().current_scene == self:
		start.call_deferred() # launched as the main scene; tests call start() or enter() themselves

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	camera.global_position = player.global_position

static func scene_path(room_name: String) -> String:
	return ROOMS_DIR + room_name.replace(" ", "") + ".tscn"

static func has_room(room_name: String) -> bool:
	return room_name != "" and ResourceLoader.exists(scene_path(room_name))

## Frees the old room, loads `room_name`, places the player at the named
## exit's arrival point (or the checkpoint's spawn point when exit_name is
## ""), keeps velocity, and records the visit.
func enter(room_name: String, exit_name: String) -> void:
	if not has_room(room_name):
		room_name = WorldGraph.START
	if room != null:
		remove_child(room)
		room.queue_free()
	room = load(scene_path(room_name)).instantiate()
	add_child(room)
	move_child(room, 0) # drawn under the player
	for e in room.exits():
		e.crossed.connect(_on_exit_crossed)
	var velocity := player.velocity
	var exit := room.exit_named(exit_name) if exit_name != "" else null
	if exit != null:
		player.global_position = exit.arrival_point()
	elif room.checkpoint() != null:
		player.global_position = room.checkpoint().spawn_point()
	elif not room.exits().is_empty():
		player.global_position = room.exits()[0].arrival_point()
	else:
		player.global_position = room.bounds().get_center()
	player.velocity = velocity
	player.tracker.compartments.clear()
	player.grabbed = false
	var b := room.bounds()
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	WorldState.visit(room_name)
	$Map.set_current(room_name)
	_cooldown = SWAP_COOLDOWN

func _on_exit_crossed(exit: Exit) -> void:
	if _cooldown > 0.0 or room == null or player.dead:
		return
	var edge := WorldGraph.edge(room.room_name, exit.exit_name)
	if edge.is_empty():
		return
	# The rooms' doors are what stop the player; this is the backstop, so a
	# gap in the geometry can never cross an edge the graph forbids. A
	# refused player is set back inside the doorway, never left in the hull.
	var state := {"ring_on": WorldState.ring_on, "vents_open": WorldState.vents_open, "boss_down": WorldState.boss_down}
	if not WorldGraph.allows(edge[4], state):
		player.global_position = exit.arrival_point()
		player.velocity = Vector2.ZERO
		return
	_cooldown = SWAP_COOLDOWN
	enter.call_deferred(edge[2], edge[3])

## Loads the save, presets switches from launch options, enters the
## checkpoint room (or the Dock), and shows the title once per launch.
func start() -> void:
	WorldState.load()
	if LaunchOptions.value("ring") == "off":
		WorldState.set_ring(false)
	if LaunchOptions.value("vents") == "open":
		WorldState.set_vents(true)
	if LaunchOptions.has("room"):
		var wanted := LaunchOptions.value("room").uri_decode()
		enter(wanted, "")
		if room.checkpoint() == null and not room.exits().is_empty():
			player.global_position = room.exits()[0].arrival_point()
	else:
		enter(WorldState.checkpoint if has_room(WorldState.checkpoint) else WorldGraph.START, "")
		if not Title.seen:
			$Title.show_title()

## The death flow's lookup: the room of the checkpoint rested at, or the Dock.
func _checkpoint_for(room_name: String) -> Checkpoint:
	enter(room_name if has_room(room_name) else WorldGraph.START, "")
	return room.checkpoint()
