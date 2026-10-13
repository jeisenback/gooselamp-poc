extends TestCase

func test_the_player_rig_has_every_pose() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var rig: Rig = p.get_node("Rig")
	var anim: AnimationPlayer = rig.get_node("Anim")
	for pose in Rig.POSES:
		assert_true(anim.has_animation(pose), "has %s" % pose)

func test_poses_follow_movement() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(frame_count(0.25)) # the spawn is a few px up; let it land
	var anim: AnimationPlayer = p.get_node("Rig/Anim")
	assert_eq(anim.current_animation, "idle", "standing")
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(3)
	assert_eq(anim.current_animation, "run", "running")
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(2)
	assert_eq(anim.current_animation, "jump", "in the air")

func test_tilts_into_velocity_only_in_zero_g() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(200, 0)
	await physics_frames(3)
	var rig: Rig = p.get_node("Rig")
	assert_true(absf(rig.rotation) > 0.1, "tilted, got %f" % rig.rotation)
	assert_true(absf(rig.rotation) <= deg_to_rad(35.0) + 0.01, "capped")
	var g := make_room(true, Vector2(2000, 1200), Vector2(5000, 0))
	p.global_position = Vector2(5000, g.floor_y - 30)
	await physics_frames(5)
	assert_eq(rig.rotation, 0.0, "upright in gravity")

func test_every_enemy_has_a_rig_with_idle_and_hit() -> void:
	for scene in ["Mite", "Drone", "Clinger", "Warden"]:
		var e: Enemy = add(load("res://scenes/%s.tscn" % scene).instantiate())
		var anim: AnimationPlayer = e.get_node("Rig/Anim")
		assert_true(anim.has_animation("idle") and anim.has_animation("hit"), "%s poses" % scene)

func test_holding_down_on_the_floor_crouches() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(frame_count(0.25))
	var anim: AnimationPlayer = p.get_node("Rig/Anim")
	p.input_override.aim = Vector2.DOWN
	await physics_frames(3)
	assert_eq(anim.current_animation, "crouch", "crouching")
	p.input_override.aim = Vector2.ZERO
	await physics_frames(3)
	assert_eq(anim.current_animation, "idle", "up again")
