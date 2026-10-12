extends TestCase

func _airlock(at: Vector2, room: String) -> Checkpoint:
	var c: Checkpoint = load("res://scenes/Checkpoint.tscn").instantiate()
	c.position = at
	c.room_name = room
	return add(c) as Checkpoint

func test_a_swing_rests_heals_saves_and_respawns_enemies() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2(Swing.REACH, r.floor_y - 40), "Dock")
	var s: Spawner = load("res://scenes/Spawner.tscn").instantiate()
	s.scene = load("res://scenes/Enemy.tscn")
	s.position = Vector2(400, r.floor_y - 16)
	add(s)
	await physics_frames(1)
	s.spawned.damage(3, Vector2.ZERO, false)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	p.take_hit(Vector2(-10, 0))
	p.invulnerable_for = 0.0
	await physics_frames(2)
	p.input_override.swing_pressed = true
	await physics_frames(3)
	p.input_override.swing_pressed = false
	assert_eq(p.health, Player.MAX_HEALTH, "healed")
	assert_eq(WorldState.checkpoint, "Dock", "checkpoint set")
	WorldState.reset()
	assert_true(WorldState.load() and WorldState.checkpoint == "Dock", "saved")
	assert_true(s.spawned is Enemy and s.spawned.health == Enemy.MAX_HEALTH, "enemies back")

func test_resting_at_full_health_with_nothing_to_respawn_is_fine() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2.ZERO, "Ring Deck")
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	a.rest(p)
	assert_eq(WorldState.checkpoint, "Ring Deck", "set")

func test_death_returns_you_to_the_checkpoint_with_the_world_as_you_left_it() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2(600, r.floor_y - 40), "Dock")
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var re := add(Respawner.new()) as Respawner
	re.bind(p, func(name): return a if a.room_name == name else null)
	a.rest(p)
	WorldState.set_ring(false)
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	assert_true(p.dead, "dead")
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	assert_true(not p.dead, "back")
	assert_true(p.global_position.distance_to(a.spawn_point()) < 2.0, "at the airlock")
	assert_true(not WorldState.ring_on, "switches untouched by death")
