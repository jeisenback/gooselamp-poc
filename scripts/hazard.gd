class_name Hazard extends StaticBody2D

## A strip of spikes or shredded hull: it hurts the player every physics
## frame they overlap it (take_hit keeps that to one per invulnerability
## window) and the swing rebounds from it, so it can be pogoed over.

@onready var hurt: Area2D = $Hurt

func _ready() -> void:
	add_to_group(Groups.HITTABLE)
	add_to_group(Groups.BOUNCY)

func _physics_process(_delta: float) -> void:
	for body in hurt.get_overlapping_bodies():
		if body.has_method("take_hit"):
			body.take_hit(global_position)

## The swing lands on it; a hazard is not damaged.
func hit(_from: Node2D, _direction: Vector2) -> void:
	pass
