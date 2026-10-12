class_name Player extends CharacterBody2D

## One input layer, two movement modes. Which mode runs depends on the
## compartment the player is in: gravity on live plates with the ring on,
## zero-g everywhere else, including outside every compartment.

const RUN_SPEED := 220.0
const RUN_ACCEL := 2400.0           # px/s^2 toward the target run speed, also the stop
const GRAVITY := 1400.0
const JUMP_SPEED := 520.0
const JUMP_CUT_SPEED := 150.0       # releasing jump while rising caps upward speed here
const KICK_SPEED := RUN_SPEED * 1.4
const RECOIL_SPEED := RUN_SPEED * 0.8
const FIRE_COOLDOWN := 0.5
const MAX_HEALTH := 5
const INVULNERABLE := 0.6
const KNOCKBACK_SPEED := 250.0
const DEATH_DELAY := 1.0            # seconds the body lies there before whoever listens respawns it

signal fired(direction: Vector2)    # Plan 2 spawns the projectile
signal health_changed(health: int)
signal died

var input_override: PlayerInput = null   # tests set this; null polls real input
var tracker := CompartmentTracker.new()  # every compartment currently overlapping, last entered last
var facing: int = 1                 # +1 right, -1 left
var grabbed: bool = false
var grab_normal: Vector2 = Vector2.ZERO
var jumping: bool = false           # a floor jump is in progress; releasing jump cuts only that rise
var health: int = MAX_HEALTH
var invulnerable_for: float = 0.0
var dead: bool = false              # no input, no damage while true
var fire_cooldown: float = 0.0

@onready var swing: Swing = $Swing

var _last_pose: String = ""
var _gravity_mode := GravityMode.new()
var _zero_g_mode := ZeroGMode.new()

func _ready() -> void:
	add_to_group(Groups.PLAYER)
	swing.landed.connect(_on_swing_landed)

func _physics_process(delta: float) -> void:
	var input: PlayerInput = input_override if input_override != null else PlayerInput.poll()
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	invulnerable_for = maxf(0.0, invulnerable_for - delta)
	if dead:
		_lie_there(delta)
	elif in_zero_g():
		_zero_g_mode.step(self, input, delta)
	else:
		_gravity_mode.step(self, input, delta)
	_update_pose()

## The rig follows what the body is doing.
func _update_pose() -> void:
	var rig := get_node_or_null("Rig") as Rig
	if rig == null:
		return
	rig.face(facing)
	rig.tilt_into(velocity, in_zero_g())
	var pose := "idle"
	if dead:
		pose = "death"
	elif swing.is_active():
		pose = "swing"
	elif invulnerable_for > INVULNERABLE - 0.2:
		pose = "hit"
	elif in_zero_g():
		pose = "idle" if grabbed else "jump"
	elif not is_on_floor():
		pose = "jump"
	elif absf(velocity.x) > 1.0:
		pose = "run"
	if pose != _last_pose:
		_last_pose = pose
		rig.play(pose)

## Dead: no input. In gravity the body lands and stops; in zero-g it drifts.
func _lie_there(delta: float) -> void:
	if not in_zero_g():
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		velocity.x = move_toward(velocity.x, 0.0, RUN_ACCEL * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
	move_and_slide()

## One health, knockback away from `from`, a short invulnerability. False
## while invulnerable or dead. At zero health the player dies.
func take_hit(from: Vector2) -> bool:
	if dead or invulnerable_for > 0.0:
		return false
	health -= 1
	invulnerable_for = INVULNERABLE
	if in_zero_g():
		velocity += (global_position - from).normalized() * KNOCKBACK_SPEED
	else:
		var side := signf(global_position.x - from.x)
		if side == 0.0:
			side = -facing
		velocity = Vector2(side * KNOCKBACK_SPEED, -KNOCKBACK_SPEED * 0.6)
	grabbed = false
	health_changed.emit(health)
	if health <= 0:
		dead = true
		Sfx.play("death")
		died.emit()
	else:
		Sfx.play("hit")
	return true

func heal_full() -> void:
	if health != MAX_HEALTH:
		health = MAX_HEALTH
		health_changed.emit(health)

## Full health, alive, still, holding nothing, at `at`.
func respawn(at: Vector2) -> void:
	dead = false
	invulnerable_for = 0.0
	velocity = Vector2.ZERO
	grabbed = false
	jumping = false
	global_position = at
	heal_full()

## True when outside every compartment or when the last one entered has no gravity.
func in_zero_g() -> bool:
	return tracker.zero_g()

func enter_compartment(c: Compartment) -> void:
	tracker.enter(c)

func exit_compartment(c: Compartment) -> void:
	tracker.exit(c)

## False while cooling down. Emits `fired` and starts the cooldown.
func fire(direction: Vector2) -> bool:
	if fire_cooldown > 0.0:
		return false
	fire_cooldown = FIRE_COOLDOWN
	Sfx.play("shot")
	if get_parent() != null:
		Shot.spawn(get_parent(), self, global_position + direction * 24.0, direction, true)
	fired.emit(direction)
	return true

## Where a swing goes. In gravity: up, down only in the air, else forward.
## In zero-g: the aim, else forward.
func aim_for_swing(input: PlayerInput) -> Vector2:
	if in_zero_g():
		return input.aim if input.aim != Vector2.ZERO else Vector2(facing, 0)
	if input.aim.y < 0.0:
		return Vector2.UP
	if input.aim.y > 0.0 and not is_on_floor():
		return Vector2.DOWN
	return Vector2(facing, 0)

func _on_swing_landed(target: Node2D, dir: Vector2) -> void:
	if target.has_method("hit"):
		target.hit(self, dir)
	if target is Enemy:
		HitStop.freeze(get_tree(), [self, target])
	if not target.is_in_group(Groups.BOUNCY):
		return # panels and doors are hit, not bounced from
	if in_zero_g():
		velocity = -dir * KICK_SPEED # ricochet: pogo without a floor
		grabbed = false
	elif dir == Vector2.DOWN:
		velocity.y = -JUMP_SPEED # pogo: a full rise, whatever the jump button is doing
		jumping = false
