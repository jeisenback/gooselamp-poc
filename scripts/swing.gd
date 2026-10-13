class_name Swing extends Area2D

## The player's one weapon: a short hitbox held out in the aimed direction for
## ACTIVE seconds, then RECOVERY seconds before the next swing. `landed` fires
## once per target per swing; the player decides what a landing does (a hit,
## a pogo, a ricochet).

const ACTIVE := 0.1                   # seconds the hitbox is live
const RECOVERY := 0.15                # seconds after ACTIVE before the next swing
const REACH := 40.0                   # hitbox centre offset from the player
const LOW_DROP := 16.0                # a crouched swing sits this much lower, at foot level

signal landed(target: Node2D, direction: Vector2)   # once per target per swing

var direction: Vector2 = Vector2.ZERO

var _timer: float = 0.0               # counts down through ACTIVE then RECOVERY
var _hit: Array[Node2D] = []

func _ready() -> void:
	monitoring = false

## False if active or recovering. `low` drops the hitbox to foot level (a crouched swing).
func start(dir: Vector2, low: bool = false) -> bool:
	if is_busy():
		return false
	direction = dir
	position = dir * REACH + (Vector2(0, LOW_DROP) if low else Vector2.ZERO)
	rotation = dir.angle()
	_timer = ACTIVE + RECOVERY
	_hit.clear()
	monitoring = true
	Sfx.play("swing")
	return true

func is_busy() -> bool:
	return _timer > 0.0

func is_active() -> bool:
	return _timer > RECOVERY

func _physics_process(delta: float) -> void:
	if is_active():
		for body in get_overlapping_bodies():
			if body is Node2D and not _hit.has(body):
				_hit.append(body)
				landed.emit(body, direction)
	_timer = maxf(0.0, _timer - delta)
	if monitoring and not is_active():
		monitoring = false
