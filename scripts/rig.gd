class_name Rig extends Node2D

## A posed polygon character: a Skeleton2D of Bone2D parts, an
## AnimationPlayer named Anim with one animation per pose, and (on the
## player) a Line2D cloth that streams behind the body's velocity. In zero-g
## the whole rig tilts into its velocity.

const POSES := ["idle", "run", "jump", "swing", "hit", "death"]
const TILT := 35.0 * PI / 180.0
const CLOTH_LINK := 5.0
const SHOULDER := Vector2(0, -10)

@onready var anim: AnimationPlayer = $Anim

var _pose: String = ""

## No restart when already playing it, except "swing" and "hit", which
## always start over. A playing "hit" finishes before anything but another
## hit or a death replaces it.
func play(pose: String) -> void:
	if anim == null or not anim.has_animation(pose):
		return
	var playing := anim.is_playing()
	if playing and _pose == pose and pose != "swing" and pose != "hit":
		return
	if playing and _pose == "hit" and pose != "hit" and pose != "death":
		return
	_pose = pose
	anim.play(pose)

## Flips x.
func face(direction: int) -> void:
	if direction != 0:
		scale.x = absf(scale.x) * signf(direction)

## Zero-g: lean into the velocity, cloth trailing opposite it. Gravity: upright, cloth hanging.
func tilt_into(velocity: Vector2, zero_g: bool) -> void:
	rotation = clampf(velocity.x / 400.0, -1.0, 1.0) * TILT if zero_g else 0.0
	var cloth := get_node_or_null("Cloth") as Line2D
	if cloth == null:
		return
	var dir := -velocity.normalized() if zero_g and velocity.length() > 1.0 else Vector2(-0.35, 1.0).normalized()
	var local := dir.rotated(-rotation) # into rig space: undo the tilt, then the flip
	local.x *= signf(scale.x)
	var points := PackedVector2Array()
	for i in range(cloth.get_point_count()):
		points.append(SHOULDER + local * CLOTH_LINK * i)
	cloth.points = points
