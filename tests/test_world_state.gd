extends TestCase

func test_start_state() -> void:
	WorldState.reset()
	assert_true(WorldState.ring_on, "ring on")
	assert_true(not WorldState.vents_open, "vents closed")
	assert_true(not WorldState.boss_down, "boss alive")
	assert_eq(WorldState.checkpoint, "", "no checkpoint")
	assert_eq(WorldState.visited.size(), 0, "nothing visited")

## Rooms re-apply when the version differs from the one they last saw. A
## reset that returned to version 0 let a reset followed by the same flips
## land on a number a room had already seen, and the room kept stale doors.
func test_reset_is_a_change_the_version_never_repeats() -> void:
	WorldState.reset()
	var seen := [WorldState.version]
	WorldState.set_ring(false)
	seen.append(WorldState.version)
	WorldState.reset()
	assert_true(not seen.has(WorldState.version), "a reset bumps the version, got %d after %s" % [WorldState.version, seen])
	seen.append(WorldState.version)
	WorldState.set_ring(false)
	assert_true(not seen.has(WorldState.version), "the flips after it never repeat a number, got %d after %s" % [WorldState.version, seen])

func test_setters_bump_version_only_on_change() -> void:
	var v0 := WorldState.version
	WorldState.set_ring(true)
	assert_eq(WorldState.version, v0, "same value: no bump")
	WorldState.set_ring(false)
	assert_eq(WorldState.version, v0 + 1, "changed: bump")
	WorldState.flip("vents")
	assert_true(WorldState.vents_open, "flip opens")
	assert_eq(WorldState.switch_state("vents"), true, "switch_state reads it")
	assert_eq(WorldState.switch_state("ring"), false, "ring is off")
	WorldState.visit("Dock")
	WorldState.visit("Dock")
	assert_eq(WorldState.visited.size(), 1, "visit is idempotent")
	assert_eq(WorldState.version, v0 + 3, "ring, vents, one visit")

func test_save_and_load_round_trip() -> void:
	WorldState.set_ring(false)
	WorldState.set_vents(true)
	WorldState.set_boss_down()
	WorldState.set_checkpoint("Ring Deck")
	WorldState.visit("Dock")
	WorldState.visit("Breach")
	WorldState.save()
	WorldState.reset()
	assert_true(WorldState.load(), "a file was loaded")
	assert_true(not WorldState.ring_on and WorldState.vents_open and WorldState.boss_down, "switches and boss")
	assert_eq(WorldState.checkpoint, "Ring Deck", "checkpoint")
	assert_eq(Array(WorldState.visited), ["Dock", "Breach"], "visited, in order")

func test_load_with_no_file_or_a_bad_file_keeps_the_start_state() -> void:
	assert_true(not WorldState.load(), "no file: false")
	assert_true(WorldState.ring_on, "state untouched")
	var f := FileAccess.open(WorldState.path_override, FileAccess.WRITE)
	f.store_string("not a config file [[[")
	f.close()
	assert_true(not WorldState.load(), "bad file: false")
	assert_true(WorldState.ring_on and not WorldState.vents_open, "state untouched")
