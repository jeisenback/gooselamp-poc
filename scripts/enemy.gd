class_name Enemy extends CharacterBody2D

## What every enemy shares: health, knockback, stagger, contact damage,
## compartment tracking and death. One behaviour script per type overrides
## `behave`. Layer 3, mask 1; in Groups.HITTABLE, ENEMY and BOUNCY.

const MAX_HEALTH := 3
const KNOCKBACK := 150.0
const STAGGER := 0.4
const SHARDS := 8

signal died

var health: int = MAX_HEALTH
var staggered_for: float = 0.0
var tracker := CompartmentTracker.new()
var dead: bool = false

func _ready() -> void:
	add_to_group(Groups.HITTABLE)
	add_to_group(Groups.ENEMY)
	add_to_group(Groups.BOUNCY)

func _physics_process(delta: float) -> void:
	if dead:
		return
	staggered_for = maxf(0.0, staggered_for - delta)
	if staggered_for <= 0.0:
		behave(delta)
	move_and_slide()
	var hurt := get_node_or_null("Hurt") as Area2D
	if hurt != null:
		for body in hurt.get_overlapping_bodies():
			if body is Player:
				body.take_hit(global_position)

func in_zero_g() -> bool:
	return tracker.zero_g()

func enter_compartment(c: Compartment) -> void:
	tracker.enter(c)

func exit_compartment(c: Compartment) -> void:
	tracker.exit(c)

## Health down, knocked away from `from`, staggered if asked. At zero: die().
func damage(amount: int, from: Vector2, stagger: bool) -> void:
	if dead:
		return
	health -= amount
	velocity = (global_position - from).normalized() * KNOCKBACK
	if stagger:
		staggered_for = STAGGER
	_flash()
	Sfx.play("hit")
	if health <= 0:
		die()

## The body goes white for the hit stop's frames.
func _flash() -> void:
	var body := get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	body.modulate = Color(8, 8, 8)
	var tween := body.create_tween() # bound to the body: dies with it, waits out a hit stop
	tween.tween_interval(HitStop.FRAMES / 60.0)
	tween.tween_property(body, "modulate", Color.WHITE, 0.0)

## The swing.
func hit(from: Node2D, _direction: Vector2) -> void:
	damage(1, from.global_position, false)

## Once: `died`, a burst of shards left in the tree, the death sound, freed.
func die() -> void:
	if dead:
		return
	dead = true
	var shards := get_node_or_null("Shards") as CPUParticles2D
	if shards != null and get_parent() != null:
		remove_child(shards)
		get_parent().add_child(shards)
		shards.global_position = global_position
		shards.emitting = true
		get_tree().create_timer(shards.lifetime + 0.2).timeout.connect(shards.queue_free)
	Sfx.play("death")
	died.emit()
	queue_free()

## Overridden per type. Not called while staggered or dead.
func behave(_delta: float) -> void:
	pass
