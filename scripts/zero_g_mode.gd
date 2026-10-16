class_name ZeroGMode extends RefCounted

## The player without gravity: the stick thrusts (no drag, so you drift
## when you let go), grab any surface to stop dead, kick off it. The gun
## is just a gun here: no recoil, and firing keeps a grab.

const GRAB_RANGE := 14.0   # a near-miss this close to a surface still catches, held or not
const KICK_GRACE := 0.15   # seconds after a kick before grab can re-latch what was just kicked off

func step(p: Player, input: PlayerInput, delta: float) -> void:
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	p.crouching = false
	if input.aim.x != 0.0:
		p.facing = 1 if input.aim.x > 0.0 else -1
	if not input.grab_held:
		p.grabbed = false
	var kicked := false
	if p.grabbed and input.jump_pressed:
		var dir := input.aim if input.aim != Vector2.ZERO else p.grab_normal
		p.velocity = dir * Player.KICK_SPEED
		p.grabbed = false
		p.grab_cooldown = KICK_GRACE
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
	if input.grab_held and p.grab_cooldown <= 0.0:
		# Any contact catches, moving in or just sliding along; a near miss within
		# GRAB_RANGE catches too. grab_cooldown alone keeps a kick from instantly
		# re-latching what it just kicked off.
		var normal := Vector2.ZERO
		var found := false
		if p.get_slide_collision_count() > 0:
			normal = p.get_slide_collision(0).get_normal()
			found = true
		elif arriving.length() > 0.0:
			var probe := p.move_and_collide(arriving.normalized() * GRAB_RANGE, true)
			if probe != null:
				normal = probe.get_normal()
				found = true
				p.global_position += probe.get_travel() # close the gap: a catch lands you on the surface, not short of it
		if found:
			if not p.grabbed:
				Sfx.play("grab")
			p.grabbed = true
			p.grab_normal = normal
			p.velocity = Vector2.ZERO
