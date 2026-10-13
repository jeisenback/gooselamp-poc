extends TestCase

## PlayerInput.poll reads the named actions; Input.action_press feeds them.

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

func test_a_stick_aims_in_any_direction() -> void:
	Input.action_press("move_right", 1.0)
	Input.action_press("move_up", 0.5)
	var aim := PlayerInput.poll().aim
	_release_all()
	assert_true(aim.is_equal_approx(Vector2(1.0, -0.5).normalized()), "the stick's own direction, got %s" % aim)

func test_keys_aim_on_the_eight_directions() -> void:
	Input.action_press("move_left")
	Input.action_press("move_down")
	var aim := PlayerInput.poll().aim
	_release_all()
	assert_true(aim.is_equal_approx(Vector2(-1, 1).normalized()), "a diagonal, got %s" % aim)

func test_a_stick_inside_the_deadzone_does_not_aim() -> void:
	Input.action_press("move_right", 0.3)
	var aim := PlayerInput.poll().aim
	_release_all()
	assert_eq(aim, Vector2.ZERO, "a drifting thumb is not an aim")
