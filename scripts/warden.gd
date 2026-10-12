class_name Warden extends Enemy

## The boss: a large drone built to patrol the gravity ring. With gravity on
## it hovers out of reach, sweeping in arcs, and repairs when not pressured.
## With gravity off it charges across the room and can be reached. Gravity
## returning mid-charge staggers it down into reach. Killing it opens the
## boss door for good.

const MAX_HEALTH_WARDEN := 24
const HALF_SIZE := 50.0
const HOVER_HEIGHT := 280.0          # gravity: above the floor, out of reach
const ARC_SPEED := 300.0
const ARC_AMPLITUDE := 40.0
const ARC_PERIOD := 2.5
const ZERO_G_WINDUP := 0.4
const CHARGE_SPEED := 520.0
const CHARGE_TIME := 0.6
const CHARGE_REST := 1.5
const STAGGER_TIME := 2.0
const STAGGER_HEIGHT := 60.0         # it sinks to here, within reach
const REPAIR_AFTER := 3.0            # seconds without damage, gravity on, before it repairs
const REPAIR_INTERVAL := 1.5         # one health per
const REST_DRIFT := 60.0

enum State { ARC, WINDUP, CHARGE, REST, STAGGER }

var state: State = State.ARC
var since_damage: float = 0.0
var was_zero_g: bool = false

var _started: bool = false
var _timer: float = 0.0
var _arc_time: float = 0.0
var _sweep: int = 1
var _repair_clock: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super._ready()
	health = MAX_HEALTH_WARDEN

func behave(delta: float) -> void:
	var zero_g := in_zero_g()
	if not _started:
		_started = true
		was_zero_g = zero_g
		_enter(State.WINDUP if zero_g else State.ARC)
	elif zero_g != was_zero_g:
		was_zero_g = zero_g
		if zero_g:
			_enter(State.WINDUP)
		elif state == State.CHARGE:
			_enter(State.STAGGER) # caught mid-charge by the ring coming back
		else:
			_enter(State.ARC)
	since_damage += delta
	_timer -= delta
	var player := nearest_player()
	match state:
		State.ARC:
			_arc_time += delta
			if is_on_wall():
				_sweep = -_sweep
			velocity.x = _sweep * ARC_SPEED
			var floor_y := _floor_y()
			if not is_nan(floor_y):
				var wanted := floor_y - HOVER_HEIGHT + sin(_arc_time * TAU / ARC_PERIOD) * ARC_AMPLITUDE
				velocity.y = clampf((wanted - global_position.y) / delta, -ARC_SPEED, ARC_SPEED)
			else:
				velocity.y = 0.0
			_repair(delta)
		State.WINDUP:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				var to_player := (player.global_position - global_position) if player != null else Vector2(_charge_direction.x, 0)
				_charge_direction = to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT
				_enter(State.CHARGE)
		State.CHARGE:
			velocity = _charge_direction * CHARGE_SPEED
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				_enter(State.REST)
		State.REST:
			velocity = (player.global_position - global_position).normalized() * REST_DRIFT if player != null else Vector2.ZERO
			if _timer <= 0.0:
				_enter(State.WINDUP)
		State.STAGGER:
			velocity.x = 0.0
			var floor_y := _floor_y()
			velocity.y = 0.0 if is_nan(floor_y) else clampf((floor_y - STAGGER_HEIGHT - global_position.y) / delta, -ARC_SPEED, ARC_SPEED)
			if _timer <= 0.0:
				_enter(State.ARC)

func _enter(next: State) -> void:
	state = next
	match next:
		State.WINDUP: _timer = ZERO_G_WINDUP
		State.CHARGE: _timer = CHARGE_TIME
		State.REST: _timer = CHARGE_REST
		State.STAGGER:
			_timer = STAGGER_TIME
			velocity = Vector2.ZERO
		State.ARC:
			_repair_clock = 0.0

## One health per REPAIR_INTERVAL once it has gone REPAIR_AFTER without damage.
func _repair(delta: float) -> void:
	if since_damage < REPAIR_AFTER or health >= MAX_HEALTH_WARDEN:
		_repair_clock = 0.0
		return
	_repair_clock += delta
	if _repair_clock >= REPAIR_INTERVAL:
		_repair_clock = 0.0
		health = mini(health + 1, MAX_HEALTH_WARDEN)

func _floor_y() -> float:
	var ray := get_node_or_null("Down") as RayCast2D
	if ray != null and ray.is_colliding():
		return ray.get_collision_point().y
	return NAN

func pose_name() -> String:
	return "swing" if state == State.CHARGE else "idle"

## Shots chip it but never stagger it; every hit resets the repair clock.
func damage(amount: int, from: Vector2, _stagger: bool) -> void:
	since_damage = 0.0
	super.damage(amount, from, false)

## Opens the boss door for good, with three times the shards.
func die() -> void:
	if dead:
		return
	WorldState.set_boss_down()
	var shards := get_node_or_null("Shards") as CPUParticles2D
	if shards != null:
		shards.amount = SHARDS * 3
	super.die()
