class_name GravityMode extends RefCounted

## The player on live plates with the ring on: Hollow Knight's floor and
## nothing more. Run, variable jump, fire without recoil.

func step(p: Player, input: PlayerInput, delta: float) -> void:
	p.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	p.grabbed = false # nothing to hold on to; a hold carried over from zero-g is dropped
	p.velocity.x = move_toward(p.velocity.x, input.aim.x * Player.RUN_SPEED, Player.RUN_ACCEL * delta)
	if input.aim.x != 0.0:
		p.facing = 1 if input.aim.x > 0.0 else -1
	if not p.is_on_floor():
		p.velocity.y += Player.GRAVITY * delta
	if p.is_on_floor():
		p.jumping = false # landed (checked before a new jump starts this frame)
	if input.jump_pressed and p.is_on_floor():
		p.velocity.y = -Player.JUMP_SPEED
		p.jumping = true
	# Only a jump's own rise is cut by releasing the button: a pogo or momentum
	# brought in from zero-g keeps its speed.
	if p.jumping and not input.jump_held:
		p.velocity.y = maxf(p.velocity.y, -Player.JUMP_CUT_SPEED)
		p.jumping = false
	if input.swing_pressed:
		p.swing.start(p.aim_for_swing(input))
	if input.fire_pressed or p.fire_buffered:
		p.request_fire(input.aim if input.aim != Vector2.ZERO else Vector2(p.facing, 0))
	p.move_and_slide()
