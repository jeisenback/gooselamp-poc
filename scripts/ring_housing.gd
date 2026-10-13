class_name RingHousing extends Node2D

## The gravity ring's housing: a band of arcs along a room's ceiling that
## slides while the ring turns and stops dead when it is switched off, by the
## same rule as the Blister's dome. Drawn here so the band is seamless: one
## arc every PERIOD px from one period before the start to one past the end.

const SLIDE := 40.0        # px/s while the ring is on
const PERIOD := 192.0      # px between arcs
const COLOR := Color(0.16, 0.17, 0.2)   # tools/build_rooms.py SCENERY

@export var width: float = 1152.0

var offset: float = 0.0

func _process(delta: float) -> void:
	if WorldState.ring_on:
		offset = fmod(offset + SLIDE * delta, PERIOD)
		queue_redraw()

func _draw() -> void:
	var x := -PERIOD + offset
	while x < width + PERIOD:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 90, 60), Vector2(x - 60, 0), Vector2(x + 60, 0), Vector2(x + 90, 60), Vector2(x + 60, 48), Vector2(x, 20), Vector2(x - 60, 48)]), COLOR)
		x += PERIOD
