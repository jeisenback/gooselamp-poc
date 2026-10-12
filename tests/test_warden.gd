extends TestCase

func _warden(at: Vector2) -> Warden:
	var w: Warden = load("res://scenes/Warden.tscn").instantiate()
	w.position = at
	return add(w) as Warden

func test_out_of_reach_by_design_in_gravity() -> void:
	var jump_height := Player.JUMP_SPEED * Player.JUMP_SPEED / (2.0 * Player.GRAVITY)
	var up_swing_top := jump_height + 22.0 + Swing.REACH + 14.0
	assert_true(Warden.HOVER_HEIGHT - Warden.ARC_AMPLITUDE - Warden.HALF_SIZE > up_swing_top, "the lowest point of the arc is above an up-swing at the apex of a jump")
	assert_true(Warden.STAGGER_HEIGHT + Warden.HALF_SIZE < up_swing_top, "staggered, it is within reach")

func test_arcs_and_repairs_in_gravity() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	var w := _warden(Vector2(0, r.floor_y - Warden.HOVER_HEIGHT))
	var p := spawn_player(Vector2(-800, r.floor_y - 30))
	await physics_frames(frame_count(1.0))
	assert_eq(w.state, Warden.State.ARC, "arcing")
	assert_true(absf(w.velocity.x) > Warden.ARC_SPEED - 1.0, "sweeping")
	assert_true(absf(w.global_position.y - (r.floor_y - Warden.HOVER_HEIGHT)) <= Warden.ARC_AMPLITUDE + 2.0, "near hover height")
	w.damage(1, p.global_position, true)
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN - 1, "chipped")
	assert_eq(w.staggered_for, 0.0, "a shot does not stagger it")
	await physics_frames(frame_count(Warden.REPAIR_AFTER + Warden.REPAIR_INTERVAL + 0.1))
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN, "repaired")

func test_charges_in_zero_g_and_never_repairs_there() -> void:
	var r := make_room(false, Vector2(2000, 1200))
	var w := _warden(Vector2.ZERO)
	var p := spawn_player(Vector2(500, 0))
	w.damage(1, p.global_position, false)
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	assert_eq(w.state, Warden.State.CHARGE, "charging")
	assert_true(w.velocity.x > 0.0 and absf(w.velocity.length() - Warden.CHARGE_SPEED) < 1.0, "at the player")
	await physics_frames(frame_count(Warden.REPAIR_AFTER + Warden.REPAIR_INTERVAL + 0.5))
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN - 1, "no repair in zero-g")

func test_gravity_returning_mid_charge_staggers_it_into_reach() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	WorldState.set_ring(false)
	var w := _warden(Vector2(0, r.floor_y - 200))
	var p := spawn_player(Vector2(500, r.floor_y - 200))
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	assert_eq(w.state, Warden.State.CHARGE, "charging")
	WorldState.set_ring(true)
	await physics_frames(2)
	assert_eq(w.state, Warden.State.STAGGER, "staggered")
	await physics_frames(frame_count(1.0))
	assert_true(absf(w.global_position.y - (r.floor_y - Warden.STAGGER_HEIGHT)) < 4.0, "sunk into reach, got %f" % w.global_position.y)
	await physics_frames(frame_count(Warden.STAGGER_TIME))
	assert_eq(w.state, Warden.State.ARC, "back up")

func test_death_sets_boss_down_once_even_during_a_stagger() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	WorldState.set_ring(false)
	var w := _warden(Vector2.ZERO)
	var p := spawn_player(Vector2(500, 0))
	var deaths := []
	w.died.connect(func(): deaths.append(true))
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	WorldState.set_ring(true)
	await physics_frames(2)
	w.damage(Warden.MAX_HEALTH_WARDEN, p.global_position, false)
	WorldState.set_ring(false)
	await physics_frames(3)
	assert_true(WorldState.boss_down, "boss down")
	assert_eq(deaths.size(), 1, "once")
