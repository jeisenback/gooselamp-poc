class_name WorldGraph extends RefCounted

## The Hulk's section as data: every room, its exits, and for each exit the
## states that let the player cross it. Written by hand with the rooms. The
## reachability test walks the product of rooms and world states and fails
## on any reachable dead end; another test checks every exit here exists in
## its scene.

## name -> {grid: Rect2i (cells; x right, y down), plates_live: bool, panels: Array ("ring", "vents", "boss"), checkpoint: bool}
const ROOMS := {
	"Blister": {"grid": Rect2i(-2, 2, 1, 1), "plates_live": false, "panels": ["ring"], "checkpoint": false},
	"Breach": {"grid": Rect2i(-1, 2, 1, 1), "plates_live": false, "panels": [], "checkpoint": false},
	"Dock": {"grid": Rect2i(0, 2, 1, 1), "plates_live": true, "panels": [], "checkpoint": true},
	"Spine West": {"grid": Rect2i(1, 2, 2, 1), "plates_live": true, "panels": [], "checkpoint": false},
	"Shaft": {"grid": Rect2i(1, 0, 1, 2), "plates_live": true, "panels": [], "checkpoint": false},
	"Spine East": {"grid": Rect2i(3, 2, 1, 1), "plates_live": true, "panels": [], "checkpoint": false},
	"Vent Room": {"grid": Rect2i(4, 2, 1, 1), "plates_live": true, "panels": ["vents"], "checkpoint": false},
	"Locker": {"grid": Rect2i(4, 3, 1, 1), "plates_live": true, "panels": [], "checkpoint": false},
	"Workshop": {"grid": Rect2i(5, 2, 1, 1), "plates_live": true, "panels": [], "checkpoint": false},
	"Hangar": {"grid": Rect2i(6, 0, 1, 3), "plates_live": true, "panels": [], "checkpoint": false},
	"Ring Deck": {"grid": Rect2i(1, -1, 6, 1), "plates_live": true, "panels": [], "checkpoint": true},
	"Control Room": {"grid": Rect2i(7, -1, 1, 1), "plates_live": true, "panels": ["ring", "boss"], "checkpoint": false},
	"Exit": {"grid": Rect2i(8, -1, 1, 1), "plates_live": true, "panels": [], "checkpoint": false},
}

## [from, from_exit, to, to_exit, needs]; needs is an Array of predicate names, all must hold:
## "ring_on", "ring_off", "vents_open", "vents_closed", "boss_down". Empty means any state.
const EDGES := [
	["Blister", "east", "Breach", "west", []],
	["Breach", "west", "Blister", "east", []],
	["Breach", "east", "Dock", "west", []],
	["Dock", "west", "Breach", "east", []],
	["Dock", "east", "Spine West", "west", []],
	["Spine West", "west", "Dock", "east", []],
	["Spine West", "up", "Shaft", "down", ["ring_off"]],
	["Shaft", "down", "Spine West", "up", []],
	["Spine West", "east", "Spine East", "west", ["ring_off"]],
	["Spine East", "west", "Spine West", "east", []],
	["Spine East", "east", "Vent Room", "west", []],
	["Vent Room", "west", "Spine East", "east", []],
	["Vent Room", "down", "Locker", "up", ["vents_closed", "ring_off"]],
	["Locker", "up", "Vent Room", "down", ["vents_closed", "ring_off"]],
	["Vent Room", "east", "Workshop", "west", []],
	["Workshop", "west", "Vent Room", "east", []],
	["Workshop", "east", "Hangar", "west", ["vents_open"]],
	["Hangar", "west", "Workshop", "east", ["vents_open"]],
	["Hangar", "up", "Ring Deck", "down_east", ["ring_off"]],
	["Ring Deck", "down_east", "Hangar", "up", []],
	["Shaft", "up", "Ring Deck", "down_west", ["vents_open", "ring_off"]],
	["Ring Deck", "down_west", "Shaft", "up", ["vents_open"]],
	["Ring Deck", "east", "Control Room", "west", []],
	["Control Room", "west", "Ring Deck", "east", []],
	["Control Room", "east", "Exit", "west", ["boss_down"]],
	["Exit", "west", "Control Room", "east", ["boss_down"]],
]

const START := "Dock"
const END := "Exit"
const REQUIRED_PATH := ["Dock", "Spine West", "Dock", "Breach", "Blister", "Breach", "Dock", "Spine West", "Spine East", "Vent Room", "Workshop", "Hangar", "Ring Deck", "Control Room", "Exit"]

## The from_exit names declared for the room.
static func exits_of(room: String) -> Array[String]:
	var out: Array[String] = []
	for e in EDGES:
		if e[0] == room and not out.has(e[1]):
			out.append(e[1])
	return out

## The edge leaving that exit, or [].
static func edge(from: String, from_exit: String) -> Array:
	for e in EDGES:
		if e[0] == from and e[1] == from_exit:
			return e
	return []

## state: {ring_on, vents_open, boss_down}
static func allows(needs: Array, state: Dictionary) -> bool:
	for need in needs:
		match need:
			"ring_on": if not state.ring_on: return false
			"ring_off": if state.ring_on: return false
			"vents_open": if not state.vents_open: return false
			"vents_closed": if state.vents_open: return false
			"boss_down": if not state.boss_down: return false
			_: return false
	return true
