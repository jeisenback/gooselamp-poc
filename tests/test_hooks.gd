class_name TestHooks

## The static hooks the game exposes to tests, reset in one place. run_tests.gd
## calls reset() around every test, so no test depends on what an earlier one
## left behind. tests/test_hygiene.gd fails when a new static variable is
## neither reset here nor explained below.

## Reset by reset().
const RESET: Array = []

## Static variables that are deliberately left alone, and why.
const EXPLAINED: Dictionary = {}

## `save_path` is where the game saves while the test runs (never the player's real save).
static func reset(save_path: String = "") -> void:
	pass
