class_name Vent extends Area2D

## An open vent moves air through a compartment. While the vents are open it
## pushes every body inside: hard in zero-g, barely in gravity. Vents are the
## zero-g equivalent of platforms.

@export var direction: Vector2 = Vector2.RIGHT     # normalised on ready

const FORCE_ZERO_G := 600.0      # px/s^2: a body at rest crosses about 1200 px in 2 s
const FORCE_GRAVITY := 60.0      # a tenth

func _ready() -> void:
	direction = direction.normalized()
	var streaks := get_node_or_null("Streaks") as CPUParticles2D
	if streaks != null:
		streaks.direction = direction
		streaks.emitting = false

func is_blowing() -> bool:
	return WorldState.vents_open

func _physics_process(delta: float) -> void:
	var blowing := is_blowing()
	var streaks := get_node_or_null("Streaks") as CPUParticles2D
	if streaks != null and streaks.emitting != blowing:
		streaks.emitting = blowing
	if not blowing:
		return
	var inside := _bounds()
	for body in get_overlapping_bodies():
		if not ("velocity" in body):
			continue # a prop with nothing to push
		if not inside.has_point(body.global_position):
			continue # the overlap list is a tick stale: a body teleported out (a respawn) is not pushed again
		var zero_g: bool = body.in_zero_g() if body.has_method("in_zero_g") else true
		var force := FORCE_ZERO_G if zero_g else FORCE_GRAVITY
		body.velocity += direction * force * delta

## The Bounds rectangle in world space.
func _bounds() -> Rect2:
	var shape := $Bounds as CollisionShape2D
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	return Rect2(shape.global_position - size / 2.0, size)
