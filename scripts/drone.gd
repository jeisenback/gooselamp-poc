class_name Drone extends Enemy

## Floats and faces the player, then charges in a straight line after a
## visible wind-up. In gravity it hovers a little above the floor, within
## pogo reach, and charges level; in zero-g the line crosses the whole room.
## A shot cancels its charge.

const RANGE := 400.0
const WINDUP := 0.6
const CHARGE_SPEED := 450.0
const CHARGE_TIME := 0.5
const REST := 1.0
const HOVER_HEIGHT := 70.0           # above the floor, in gravity
const DRIFT_SPEED := 40.0            # toward the player while hovering in zero-g

enum State { HOVER, WINDUP, CHARGE, REST }

var state: State = State.HOVER
var target: Player = null            # the nearest Player in the tree, found each frame
var charge_direction: Vector2 = Vector2.RIGHT

var _timer: float = 0.0

func behave(delta: float) -> void:
	target = nearest_player()
	_timer -= delta
	var zero_g := in_zero_g()
	match state:
		State.HOVER:
			_hover(delta, zero_g)
			if target != null and _in_range(zero_g):
				state = State.WINDUP
				_timer = WINDUP
		State.WINDUP:
			_hover(delta, zero_g, true)
			if _timer <= 0.0:
				_start_charge(zero_g)
		State.CHARGE:
			velocity = charge_direction * CHARGE_SPEED
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				state = State.REST
				_timer = REST
		State.REST:
			_hover(delta, zero_g, true)
			if _timer <= 0.0:
				state = State.HOVER
	_pose()

## Hover height in gravity; drift toward the player in zero-g (or hold, when still).
func _hover(delta: float, zero_g: bool, hold_still: bool = false) -> void:
	if zero_g:
		if hold_still or target == null:
			velocity = Vector2.ZERO
		else:
			velocity = (target.global_position - global_position).normalized() * DRIFT_SPEED
		return
	velocity.x = 0.0
	var ray := get_node_or_null("Down") as RayCast2D
	if ray != null and ray.is_colliding():
		var wanted_y := ray.get_collision_point().y - HOVER_HEIGHT
		var dy := wanted_y - global_position.y
		velocity.y = clampf(dy / delta, -CHARGE_SPEED, CHARGE_SPEED)
	else:
		velocity.y = 0.0

## In gravity the drone lives at floor height, so range is horizontal; in zero-g it is the full distance.
func _in_range(zero_g: bool) -> bool:
	if zero_g:
		return global_position.distance_to(target.global_position) <= RANGE
	return absf(target.global_position.x - global_position.x) <= RANGE

func _start_charge(zero_g: bool) -> void:
	var to_target := (target.global_position - global_position) if target != null else Vector2(charge_direction.x, 0)
	if zero_g:
		charge_direction = to_target.normalized() if to_target != Vector2.ZERO else Vector2.RIGHT
	else:
		charge_direction = Vector2(signf(to_target.x) if to_target.x != 0.0 else 1.0, 0.0)
	state = State.CHARGE
	_timer = CHARGE_TIME

## A stagger cancels whatever it was doing.
func damage(amount: int, from: Vector2, stagger: bool) -> void:
	super.damage(amount, from, stagger)
	if stagger and not dead:
		state = State.HOVER
		velocity = Vector2.ZERO

func _pose() -> void:
	var body := find_child("Body", true, false) as Node2D
	if body == null:
		return
	var size := 1.3 if state == State.WINDUP else 1.0
	var face := 1.0
	if target != null and target.global_position.x < global_position.x:
		face = -1.0
	body.scale = Vector2(face * size, size)
