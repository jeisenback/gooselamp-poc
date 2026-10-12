class_name Clinger extends Enemy

## A turret on a surface that spits a slow shot at the player. Fixed in
## gravity. In zero-g it is debris: it drifts, the vents push it, and it
## keeps shooting.

const RANGE := 500.0
const PERIOD := 2.0

var since_shot: float = 0.0

func behave(delta: float) -> void:
	if in_zero_g():
		pass # drift: whatever velocity it has, it keeps; the vents add to it
	else:
		velocity.x = 0.0
		velocity.y = 0.0 if is_on_floor() else velocity.y + Player.GRAVITY * delta
	since_shot += delta
	var player := nearest_player()
	if player == null or global_position.distance_to(player.global_position) > RANGE:
		return
	if since_shot >= PERIOD:
		since_shot = 0.0
		var dir := (player.global_position - global_position).normalized()
		Shot.spawn(get_parent(), self, global_position, dir, false)
		Sfx.play("shot", -6.0)
