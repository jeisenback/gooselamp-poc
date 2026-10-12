class_name WorldState extends RefCounted

## The world's state: the two switches, the boss flag, the last airlock rested
## at, and the rooms seen. The only thing that knows what a state means.
## Rooms poll `version`, which bumps on every change. Saves and loads itself
## to one ConfigFile.

const SAVE_PATH := "user://save.cfg"
const SECTION := "world"

static var ring_on: bool = true
static var vents_open: bool = false
static var boss_down: bool = false
static var checkpoint: String = ""        # room name of the last airlock rested at; "" means the Dock start
static var visited: PackedStringArray = []
static var version: int = 0               # bumps on every change; rooms poll it
static var path_override: String = ""     # tests save here instead of SAVE_PATH

## The start state, version 0.
static func reset() -> void:
	ring_on = true
	vents_open = false
	boss_down = false
	checkpoint = ""
	visited = []
	version = 0

static func set_ring(on: bool) -> void:
	if ring_on != on:
		ring_on = on
		version += 1

static func set_vents(open: bool) -> void:
	if vents_open != open:
		vents_open = open
		version += 1

## "ring" or "vents".
static func flip(switch_name: String) -> void:
	match switch_name:
		"ring": set_ring(not ring_on)
		"vents": set_vents(not vents_open)
		_: push_error("no switch named %s" % switch_name)

static func switch_state(switch_name: String) -> bool:
	match switch_name:
		"ring": return ring_on
		"vents": return vents_open
	push_error("no switch named %s" % switch_name)
	return false

static func set_boss_down() -> void:
	if not boss_down:
		boss_down = true
		version += 1

static func set_checkpoint(room: String) -> void:
	if checkpoint != room:
		checkpoint = room
		version += 1

## No duplicates.
static func visit(room: String) -> void:
	if not visited.has(room):
		visited.append(room)
		version += 1

static func _path() -> String:
	return path_override if path_override != "" else SAVE_PATH

static func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "ring_on", ring_on)
	file.set_value(SECTION, "vents_open", vents_open)
	file.set_value(SECTION, "boss_down", boss_down)
	file.set_value(SECTION, "checkpoint", checkpoint)
	file.set_value(SECTION, "visited", visited)
	file.save(_path())

## False, and the state unchanged, when there is no file or a bad one.
static func load() -> bool:
	var file := ConfigFile.new()
	if file.load(_path()) != OK or not file.has_section(SECTION):
		return false # ConfigFile accepts garbage as an empty file; no section means no save
	ring_on = file.get_value(SECTION, "ring_on", true)
	vents_open = file.get_value(SECTION, "vents_open", false)
	boss_down = file.get_value(SECTION, "boss_down", false)
	checkpoint = file.get_value(SECTION, "checkpoint", "")
	visited = PackedStringArray(file.get_value(SECTION, "visited", PackedStringArray()))
	version += 1
	return true
