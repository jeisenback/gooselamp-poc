class_name Mite extends Enemy

## The hull mite crawls along any surface in either state, following walls
## and ceilings, stuck to its surface and deaf to gravity. Slow and predictable.

const SPEED := 60.0
const PROBE := 4.0                     # how far past the feet it looks for ground
const RADIUS := 8.0

var normal: Vector2 = Vector2.UP       # away from the surface it stands on
var turn: int = 1                      # +1 or -1: which way around the surface it crawls

func tangent() -> Vector2:
	return Vector2(-normal.y, normal.x) * turn

func behave(delta: float) -> void:
	# Knockback is a one-frame shove, never a lasting velocity: the mite stays stuck.
	global_position += velocity * delta
	velocity = Vector2.ZERO
	# Surfaces run on through doorways into the next room; a mite turns back at its room's edge.
	if home != null and not home.bounds().grow(-RADIUS).has_point(global_position + tangent() * SPEED * delta):
		turn = -turn
	var collision := move_and_collide(tangent() * SPEED * delta)
	if collision != null:
		normal = collision.get_normal() # a concave corner: turn up the next face
	elif not test_move(global_transform, -normal * PROBE):
		# A convex corner: the face ran out. Wrap round onto the next one.
		var old_normal := normal
		normal = tangent()
		global_position += (normal - old_normal) * RADIUS
	var body := find_child("Body", true, false) as Node2D
	if body != null:
		body.rotation = normal.angle() + PI / 2.0
