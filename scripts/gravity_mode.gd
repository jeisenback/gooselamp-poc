class_name GravityMode extends RefCounted

## The player on live plates with the ring on: Hollow Knight's floor and
## nothing more. Run, variable jump, fire without recoil.

func step(p: Player, input: PlayerInput, delta: float) -> void:
	p.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	p.velocity.x = move_toward(p.velocity.x, input.aim.x * Player.RUN_SPEED, Player.RUN_ACCEL * delta)
	if input.aim.x != 0.0:
		p.facing = 1 if input.aim.x > 0.0 else -1
	if not p.is_on_floor():
		p.velocity.y += Player.GRAVITY * delta
	if input.jump_pressed and p.is_on_floor():
		p.velocity.y = -Player.JUMP_SPEED
	if p.velocity.y < -Player.JUMP_CUT_SPEED and not input.jump_held:
		p.velocity.y = -Player.JUMP_CUT_SPEED
	if input.fire_pressed:
		p.fire(input.aim if input.aim != Vector2.ZERO else Vector2(p.facing, 0))
	p.move_and_slide()
