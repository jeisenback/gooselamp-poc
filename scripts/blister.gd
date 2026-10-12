class_name Blister extends Room

## The observation dome. Its background is the ring itself, turning slowly
## while the ring is on and stopping dead when it is switched off.

const TURN := 0.35   # radians per second

func _process(delta: float) -> void:
	if WorldState.ring_on:
		$Ring.rotation += TURN * delta
