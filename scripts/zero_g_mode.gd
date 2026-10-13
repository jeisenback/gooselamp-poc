class_name ZeroGMode extends RefCounted

## The player without gravity: the stick thrusts (no drag, so you drift
## when you let go), grab any surface to stop dead, kick off it. The gun
## is just a gun here: no recoil, and firing keeps a grab.

func step(p: Player, input: PlayerInput, delta: float) -> void:
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if input.aim.x != 0.0:
		p.facing = 1 if input.aim.x > 0.0 else -1
	if not input.grab_held:
		p.grabbed = false
	var kicked := false
	if p.grabbed and input.jump_pressed:
		var dir := input.aim if input.aim != Vector2.ZERO else p.grab_normal
		p.velocity = dir * Player.KICK_SPEED
		p.grabbed = false
		kicked = true
		Sfx.play("kick")
	if input.swing_pressed:
		p.swing.start(p.aim_for_swing(input))
	if input.fire_pressed or p.fire_buffered:
		p.request_fire(input.aim if input.aim != Vector2.ZERO else Vector2(p.facing, 0))
	if p.grabbed:
		p.velocity = Vector2.ZERO
		return # held fast: no movement at all
	if input.aim != Vector2.ZERO and not kicked:
		# Thrust along the stick up to THRUST_MAX; speed from elsewhere is left alone.
		var along := p.velocity.dot(input.aim)
		if along < Player.THRUST_MAX:
			p.velocity += input.aim * minf(Player.THRUST_ACCEL * delta, Player.THRUST_MAX - along)
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
