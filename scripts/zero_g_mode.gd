class_name ZeroGMode extends RefCounted

## The player without gravity: drift with momentum that never decays, grab
## any surface to stop dead, kick off it, and fire for recoil. The gun is
## the suit's only thruster.

func step(p: Player, input: PlayerInput, delta: float) -> void:
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if input.aim.x != 0.0:
		p.facing = 1 if input.aim.x > 0.0 else -1
	if not input.grab_held:
		p.grabbed = false
	if p.grabbed and input.jump_pressed:
		var dir := input.aim if input.aim != Vector2.ZERO else p.grab_normal
		p.velocity = dir * Player.KICK_SPEED
		p.grabbed = false
		Sfx.play("kick")
	if input.swing_pressed:
		p.swing.start(p.aim_for_swing(input))
	if input.fire_pressed:
		var dir := input.aim if input.aim != Vector2.ZERO else Vector2(p.facing, 0)
		if p.fire(dir):
			p.velocity += -dir * Player.RECOIL_SPEED
			p.grabbed = false
	if p.grabbed:
		p.velocity = Vector2.ZERO
		return # held fast: no movement at all
	var arriving := p.velocity
	p.move_and_slide()
	# Floating motion leaves velocity alone on a collision: a surface takes the
	# component into it, so a wall stops you and a glancing hit slides.
	for i in range(p.get_slide_collision_count()):
		var normal := p.get_slide_collision(i).get_normal()
		if p.velocity.dot(normal) < 0.0:
			p.velocity = p.velocity.slide(normal)
	if input.grab_held and p.get_slide_collision_count() > 0:
		var normal := p.get_slide_collision(0).get_normal()
		# Latch on arrival (moving into the surface) or at rest against it; a body
		# sliding along a surface it just kicked off is still in contact and must not.
		if arriving.dot(normal) < 0.0 or arriving.is_zero_approx():
			if not p.grabbed:
				Sfx.play("grab")
			p.grabbed = true
			p.grab_normal = normal
			p.velocity = Vector2.ZERO
