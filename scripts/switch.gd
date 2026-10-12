class_name Switch extends StaticBody2D

## A panel the player swings at. Flips one WorldState switch and nothing
## else. A second hit inside REHIT_DELAY is ignored, so one swing that
## overlaps the panel for a few frames flips it once.

const REHIT_DELAY := 0.3
const COLOR_ON := Color(0.95, 0.85, 0.35)
const COLOR_OFF := Color(0.35, 0.32, 0.2)

@export var switch_name: String = "ring"   # "ring" or "vents"

var _rehit: float = 0.0

func _ready() -> void:
	add_to_group(Groups.HITTABLE)
	_refresh()

func _physics_process(delta: float) -> void:
	_rehit = maxf(0.0, _rehit - delta)
	_refresh()

## Called by the swing. `from` and `direction` are unused by a panel.
func hit(_from: Node2D, _direction: Vector2) -> void:
	if _rehit > 0.0:
		return
	_rehit = REHIT_DELAY
	WorldState.flip(switch_name)
	Sfx.play("switch")
	if switch_name == "ring" and not WorldState.ring_on:
		Sfx.play("ring_down")
	_refresh()

func _refresh() -> void:
	var panel := get_node_or_null("Panel") as Polygon2D
	if panel != null:
		panel.color = COLOR_ON if WorldState.switch_state(switch_name) else COLOR_OFF
