class_name Game extends Node2D

## The game: the whole section in one scene, the player placed into it. The
## current room is the compartment the player entered last; it drives the
## camera limits, the visits and the map. Owns the player, the camera, the
## HUD, the title and the death flow.

const ROOMS_DIR := "res://scenes/rooms/"

var section: Section
var current: Room = null
var player: Player
var _camera_reset_ticks: int = 0            # after a teleport: ticks left of snapping the camera to the body
var _centre_room: Room = null               # the room whose bounds hold the body's centre, for the backstop
var backstops: int = 0                      # how often the backstop has set the player back; the door tests expect never

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	player = $Player
	$HUD.bind(player)
	$Respawner.bind(player, _checkpoint_for)
	section = Section.new()
	add_child(section)
	move_child(section, 0) # drawn under the player
	if get_tree().current_scene == self:
		start.call_deferred() # launched as the main scene; tests call start() or place() themselves

func _physics_process(_delta: float) -> void:
	_backstop()
	camera.global_position = player.global_position
	_sync_current() # the new room's limits first, so a reset lands inside them
	if _camera_reset_ticks > 0:
		_camera_reset_ticks -= 1
		camera.reset_smoothing()
		camera.reset_physics_interpolation()

## A teleport (place, respawn) must not be smoothed across the section. The
## camera's own update has to see the new position once before a reset
## sticks, so the snap is asked for on this tick and the next.
func _snap_camera() -> void:
	camera.global_position = player.global_position
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
	_camera_reset_ticks = 2

static func scene_path(room_name: String) -> String:
	return ROOMS_DIR + room_name.replace(" ", "") + ".tscn"

func has_room(room_name: String) -> bool:
	return section.room(room_name) != null

## The room of the compartment the player entered last. A dead body drifting
## through a doorway does not move the room with it.
func _sync_current() -> void:
	if player.dead or player.tracker.compartments.is_empty():
		return
	var r := player.tracker.compartments[-1].get_parent() as Room
	if r == null or r == current:
		return
	current = r
	_apply_limits(r)
	WorldState.visit(r.room_name)
	$Map.set_current(r.room_name)

## The camera is held to the room, plus a third of a screen past each side
## that has a door, so the neighbour shows through its doorway and nowhere
## else. Godot's limit smoothing turns the change at a doorway into a scroll.
func _apply_limits(r: Room) -> void:
	var b := r.bounds()
	var grow := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	for e in r.exits():
		if e.inward.x > 0.0: grow.left = Section.LOOKAHEAD
		elif e.inward.x < 0.0: grow.right = Section.LOOKAHEAD
		elif e.inward.y > 0.0: grow.top = Section.LOOKAHEAD
		elif e.inward.y < 0.0: grow.bottom = Section.LOOKAHEAD
	camera.limit_left = int(b.position.x - grow.left)
	camera.limit_top = int(b.position.y - grow.top)
	camera.limit_right = int(b.end.x + grow.right)
	camera.limit_bottom = int(b.end.y + grow.bottom)

## Puts the player at the named exit's arrival point (or the checkpoint's
## spawn point when exit_name is ""), keeps velocity, and makes that room
## current at once. A teleport, not a move: nothing loads.
func place(room_name: String, exit_name: String) -> void:
	if not has_room(room_name):
		room_name = WorldGraph.START
	var r := section.room(room_name)
	var velocity := player.velocity
	var exit := r.exit_named(exit_name) if exit_name != "" else null
	if exit != null:
		player.global_position = exit.arrival_point()
	elif r.checkpoint() != null:
		player.global_position = r.checkpoint().spawn_point()
	elif not r.exits().is_empty():
		player.global_position = r.exits()[0].arrival_point()
	else:
		player.global_position = r.bounds().get_center()
	player.velocity = velocity
	player.grabbed = false
	# Seed the compartment directly: the player is placed inside it, and
	# whether the area reports the overlap is a platform detail (the web
	# build never did for the first room, leaving the Dock in zero-g).
	player.tracker.compartments.clear()
	player.enter_compartment(r.compartment)
	_centre_room = r
	current = null
	_sync_current()
	player.reset_physics_interpolation() # no smear from where the player was
	_snap_camera()

## The room whose bounds hold a point. Rooms touch without overlapping, so
## there is at most one.
func _room_at(point: Vector2) -> Room:
	for r in section.rooms():
		if r.bounds().has_point(point):
			return r
	return null

## The backstop: the doors hold the player, but a gap in the geometry can
## never cross an edge the graph forbids. A leak is the body's centre moving
## from one room's bounds into a neighbour's along an edge the state shuts;
## the body is set back inside the doorway it left by. Standing in a shared
## doorway, or arriving through the open direction of a one-way edge, moves
## the centre along no shut edge and is left alone.
func _backstop() -> void:
	if player.dead:
		return
	var now := _room_at(player.global_position)
	if now == null or now == _centre_room:
		return
	if _centre_room != null:
		var state := {"ring_on": WorldState.ring_on, "vents_open": WorldState.vents_open, "boss_down": WorldState.boss_down}
		for e in WorldGraph.EDGES:
			if e[0] == _centre_room.room_name and e[2] == now.room_name and not WorldGraph.allows(e[4], state):
				player.global_position = _centre_room.exit_named(e[1]).arrival_point()
				player.velocity = Vector2.ZERO
				backstops += 1
				return
	_centre_room = now

## Loads the save, presets switches from launch options, places the player
## at the checkpoint (or the Dock), and shows the title once per launch.
func start() -> void:
	WorldState.load()
	if LaunchOptions.value("ring") == "off":
		WorldState.set_ring(false)
	if LaunchOptions.value("vents") == "open":
		WorldState.set_vents(true)
	if LaunchOptions.has("room"):
		place(LaunchOptions.value("room").uri_decode(), "")
	else:
		place(WorldState.checkpoint if has_room(WorldState.checkpoint) else WorldGraph.START, "")
		if not Title.seen:
			$Title.show_title()

## The death flow's lookup: the airlock of the room rested at, or the Dock's.
## Seeds that room's compartment so the first frame after the respawn has
## its gravity, and asks for a camera reset once the body has moved.
func _checkpoint_for(room_name: String) -> Checkpoint:
	var r := section.room(room_name if has_room(room_name) else WorldGraph.START)
	player.tracker.compartments.clear()
	player.enter_compartment(r.compartment)
	_centre_room = r
	_camera_reset_ticks = 2
	return r.checkpoint()
