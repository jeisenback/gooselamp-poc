extends TestCase

func test_the_porthole_shares_the_world_and_aims_at_the_control_room() -> void:
	var s: Section = add(Section.new())
	await physics_frames(1)
	var port: Porthole = s.room("Locker").get_node("ViewPort")
	assert_true(port.get_node("SubViewport").world_2d == port.get_viewport().world_2d, "one world, two cameras")
	var cam: Camera2D = port.get_node("SubViewport/Camera2D")
	assert_true(cam.global_position.is_equal_approx(s.room("Control Room").bounds().get_center()), "aimed at the Control Room, at %s" % cam.global_position)
	assert_true(cam.zoom.is_equal_approx(Vector2(Porthole.ZOOM, Porthole.ZOOM)), "zoomed")

func test_a_porthole_without_a_section_stays_quiet() -> void:
	var r: Room = add(load(Game.scene_path("Locker")).instantiate())
	await physics_frames(1)
	var port: Porthole = r.get_node("ViewPort")
	assert_true(not port.aim(), "nothing to aim at")
