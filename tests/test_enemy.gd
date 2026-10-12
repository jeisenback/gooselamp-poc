extends TestCase

func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = load("res://scenes/Enemy.tscn").instantiate()
	e.position = at
	return add(e) as Enemy

func test_three_swings_kill_and_shards_fly() -> void:
	var r := make_room(true)
	var e := _enemy(Vector2(0, r.floor_y - 16))
	var deaths := []
	e.died.connect(func(): deaths.append(true))
	var p := spawn_player(Vector2(-60, r.floor_y - 30))
	await physics_frames(2)
	e.hit(p, Vector2.RIGHT)
	assert_eq(e.health, 2, "one damage")
	assert_true(e.velocity.x > 0.0, "knocked away from the player")
	assert_eq(e.staggered_for, 0.0, "a swing does not stagger")
	e.hit(p, Vector2.RIGHT)
	e.hit(p, Vector2.RIGHT)
	assert_eq(deaths.size(), 1, "died")
	await physics_frames(2)
	assert_true(not is_instance_valid(e), "gone")
	assert_true(tree.root.get_children().any(func(n): return n is CPUParticles2D and n.emitting), "shards left behind")

func test_a_shot_staggers() -> void:
	var r := make_room(false)
	var e := _enemy(Vector2.ZERO)
	e.damage(1, Vector2(0, 100), true)
	assert_true(absf(e.staggered_for - Enemy.STAGGER) < 0.001, "staggered")
	assert_true(e.velocity.is_equal_approx(Vector2.UP * Enemy.KNOCKBACK), "knocked up, away from below")

func test_contact_hurts_the_player_once_per_window() -> void:
	var r := make_room(true)
	var e := _enemy(Vector2(0, r.floor_y - 16))
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(5)
	assert_eq(p.health, 4, "one hit while overlapping")

func test_enemies_track_compartments_like_the_player() -> void:
	var r := make_room(false)
	var e := _enemy(Vector2.ZERO)
	await physics_frames(2)
	assert_true(e.in_zero_g(), "dead plates")
	assert_eq(e.tracker.compartments.size(), 1, "inside the room's compartment")

func test_spawner_respawns_a_fresh_enemy() -> void:
	var r := make_room(true)
	var s: Spawner = load("res://scenes/Spawner.tscn").instantiate()
	s.scene = load("res://scenes/Enemy.tscn")
	s.position = Vector2(100, r.floor_y - 16)
	add(s)
	await physics_frames(1)
	var first := s.spawned
	assert_true(first is Enemy, "spawned on ready")
	first.damage(3, Vector2.ZERO, false)
	await physics_frames(2)
	Spawner.respawn_all(tree)
	await physics_frames(1)
	assert_true(s.spawned is Enemy and s.spawned != first, "a new one")
	assert_eq(s.spawned.health, Enemy.MAX_HEALTH, "at full health")
