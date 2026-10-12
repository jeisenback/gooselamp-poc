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

signal fired(direction: Vector2)    # Plan 2 spawns the projectile

var input_override: PlayerInput = null   # tests set this; null polls real input
var compartments: Array[Compartment] = []  # every compartment currently overlapping, last entered last
var facing: int = 1                 # +1 right, -1 left
var grabbed: bool = false
var grab_normal: Vector2 = Vector2.ZERO
var fire_cooldown: float = 0.0

var _gravity_mode := GravityMode.new()
var _zero_g_mode := ZeroGMode.new()

func _physics_process(delta: float) -> void:
	var input: PlayerInput = input_override if input_override != null else PlayerInput.poll()
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if in_zero_g():
		_zero_g_mode.step(self, input, delta)
	else:
		_gravity_mode.step(self, input, delta)

## True when outside every compartment or when the last one entered has no gravity.
func in_zero_g() -> bool:
	return compartments.is_empty() or not compartments[-1].has_gravity()

func enter_compartment(c: Compartment) -> void:
	compartments.erase(c)
	compartments.append(c)

func exit_compartment(c: Compartment) -> void:
	compartments.erase(c)

## False while cooling down. Emits `fired` and starts the cooldown.
func fire(direction: Vector2) -> bool:
	if fire_cooldown > 0.0:
		return false
	fire_cooldown = FIRE_COOLDOWN
	fired.emit(direction)
	return true
