class_name TestHooks

## The static hooks the game exposes to tests, reset in one place. run_tests.gd
## calls reset() around every test, so no test depends on what an earlier one
## left behind. tests/test_hygiene.gd fails when a new static variable is
## neither reset here nor explained below.

## Reset by reset().
const RESET: Array = [
	"WorldState.ring_on", "WorldState.vents_open", "WorldState.boss_down",
	"WorldState.checkpoint", "WorldState.visited", "WorldState.version",
	"WorldState.path_override", "Title.seen",
]

## Static variables that are deliberately left alone, and why.
const EXPLAINED: Dictionary = {
	"Sfx._pool": "the audio player pool, created on demand and reused",
	"Sfx._lp_state": "filter state inside one sound's synthesis",
}

## `save_path` is where WorldState saves while the test runs (never the player's real save).
static func reset(save_path: String = "") -> void:
	WorldState.reset()
	WorldState.path_override = save_path
	Title.seen = true # scene tests must not start paused on the title
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false
