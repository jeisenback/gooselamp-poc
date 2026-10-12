extends TestCase

func _compartment(live: bool) -> Compartment:
	var c: Compartment = load("res://scenes/Compartment.tscn").instantiate()
	c.plates_live = live
	(c.get_node("Bounds") as CollisionShape2D).shape.size = Vector2(800, 600)
	return c

func _with_state_children(c: Compartment) -> void:
	for state_name in ["RingOn", "RingOff", "VentsOpen", "VentsClosed"]:
		var holder := Node2D.new()
		holder.name = state_name
		var body := StaticBody2D.new()
		body.name = "StaticBody2D" # an unnamed node gets a mangled name, not its class name
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		shape.shape = RectangleShape2D.new()
		body.add_child(shape)
		holder.add_child(body)
		c.add_child(holder)

func test_gravity_follows_plates_and_the_ring() -> void:
	var live := add(_compartment(true)) as Compartment
	var dead := add(_compartment(false)) as Compartment
	assert_true(live.has_gravity(), "live plates, ring on")
	assert_true(not dead.has_gravity(), "dead plates never have gravity")
	WorldState.set_ring(false)
	assert_true(not live.has_gravity(), "ring off: no gravity anywhere")

func test_state_children_follow_the_switches() -> void:
	var c := _compartment(true)
	_with_state_children(c)
	add(c)
	await physics_frames(1)
	var shape_of := func(n: String) -> CollisionShape2D: return c.get_node(n + "/StaticBody2D/CollisionShape2D")
	assert_true(c.get_node("RingOn").visible and not c.get_node("RingOff").visible, "ring on at start")
	assert_true(shape_of.call("RingOff").disabled, "RingOff collision disabled")
	assert_true(not c.get_node("VentsOpen").visible and c.get_node("VentsClosed").visible, "vents closed at start")
	WorldState.set_ring(false)
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(not c.get_node("RingOn").visible and c.get_node("RingOff").visible, "ring flipped")
	assert_true(shape_of.call("RingOn").disabled and not shape_of.call("RingOff").disabled, "collision follows")
	assert_true(c.get_node("VentsOpen").visible and not c.get_node("VentsClosed").visible, "vents flipped")
	assert_eq(c.get_node("RingOn").process_mode, Node.PROCESS_MODE_DISABLED, "inactive children do not process")

func test_a_compartment_without_state_children_is_fine() -> void:
	var c := add(_compartment(true)) as Compartment
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(not c.has_gravity(), "no children, no error")
