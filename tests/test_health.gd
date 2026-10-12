extends TestCase

func test_a_hit_costs_one_and_knocks_back_in_gravity() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(2)
	var changes := []
	p.health_changed.connect(func(h): changes.append(h))
	assert_true(p.take_hit(Vector2(-50, r.floor_y - 30)), "hit lands")
	assert_eq(p.health, 4, "one lost")
	assert_eq(changes, [4], "signal")
	assert_true(p.velocity.x > 0.0 and p.velocity.y < 0.0, "knocked right and up, got %s" % p.velocity)
	assert_true(not p.take_hit(Vector2(-50, r.floor_y - 30)), "invulnerable right after")
	await physics_frames(frame_count(Player.INVULNERABLE) + 2)
	assert_true(p.take_hit(Vector2(-50, r.floor_y - 30)), "vulnerable again")

func test_knockback_in_zero_g_is_added_velocity() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(100, 0)
	p.take_hit(Vector2(0, 50))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -Player.KNOCKBACK_SPEED)), "pushed away from below, got %s" % p.velocity)

func test_death_at_zero_and_never_below() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var deaths := [] # an array: a lambda captures an int by value and could never count
	p.died.connect(func(): deaths.append(true))
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	assert_true(p.dead, "dead at zero")
	assert_eq(deaths.size(), 1, "died once")
	p.invulnerable_for = 0.0
	assert_true(not p.take_hit(Vector2(10, 0)), "the dead take no hits")
	assert_eq(p.health, 0, "never negative")
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(10)
	assert_true(absf(p.velocity.x) < 1.0, "no input while dead")

func test_respawn_restores_everything() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	p.respawn(Vector2(300, r.floor_y - 30))
	assert_true(not p.dead and p.health == Player.MAX_HEALTH, "alive and full")
	assert_eq(p.global_position, Vector2(300, r.floor_y - 30), "moved")
	assert_eq(p.velocity, Vector2.ZERO, "still")

func test_a_hazard_hurts_on_contact_and_can_be_pogoed() -> void:
	var r := make_room(true)
	var h: Hazard = add(load("res://scenes/Hazard.tscn").instantiate())
	h.position = Vector2(0, r.floor_y - 10)
	var p := spawn_player(Vector2(0, r.floor_y - 40))
	await physics_frames(5)
	assert_eq(p.health, 4, "touched the hazard once in the invulnerability window")
	assert_true(h.is_in_group(Groups.HITTABLE), "pogo target")
	assert_true(h.is_in_group(Groups.BOUNCY), "a hazard rebounds the swing")

func test_hud_pips_follow_health() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var hud: Hud = add(load("res://scenes/HUD.tscn").instantiate())
	hud.bind(p)
	assert_eq(hud.pips_lit(), 5, "full")
	p.take_hit(Vector2(10, 0))
	assert_eq(hud.pips_lit(), 4, "one dark")
