class_name PlayerInput extends RefCounted

## One frame of player intent, read from the named input actions. Tests
## build one by hand and set it as Player.input_override.

var aim: Vector2 = Vector2.ZERO     # a unit direction (any angle from a stick, 8 from keys) or ZERO
var jump_pressed: bool = false      # edge
var jump_held: bool = false
var swing_pressed: bool = false     # edge
var fire_pressed: bool = false      # edge
var grab_held: bool = false

static func poll() -> PlayerInput:
	var input := PlayerInput.new()
	var raw := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	input.aim = raw.normalized() if raw.length() > 0.5 else Vector2.ZERO
	input.jump_pressed = Input.is_action_just_pressed("jump")
	input.jump_held = Input.is_action_pressed("jump")
	input.swing_pressed = Input.is_action_just_pressed("swing")
	input.fire_pressed = Input.is_action_just_pressed("fire")
	input.grab_held = Input.is_action_pressed("grab")
	return input
