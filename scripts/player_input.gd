class_name PlayerInput extends RefCounted

## One frame of player intent, read from the named input actions. Tests
## build one by hand and set it as Player.input_override.

var aim: Vector2 = Vector2.ZERO     # one of 8 unit directions or ZERO, from move_* actions
var jump_pressed: bool = false      # edge
var jump_held: bool = false
var swing_pressed: bool = false     # edge
var fire_pressed: bool = false      # edge
var grab_held: bool = false

static func poll() -> PlayerInput:
	var input := PlayerInput.new()
	var x := Input.get_axis("move_left", "move_right")
	var y := Input.get_axis("move_up", "move_down")
	var snapped := Vector2(signf(x) if absf(x) > 0.5 else 0.0, signf(y) if absf(y) > 0.5 else 0.0)
	input.aim = snapped.normalized()
	input.jump_pressed = Input.is_action_just_pressed("jump")
	input.jump_held = Input.is_action_pressed("jump")
	input.swing_pressed = Input.is_action_just_pressed("swing")
	input.fire_pressed = Input.is_action_just_pressed("fire")
	input.grab_held = Input.is_action_pressed("grab")
	return input
