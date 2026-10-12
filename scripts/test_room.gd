class_name TestRoom extends Node2D

## The playable test room: two compartments and a seam. Left has live plates
## and a floor, right has dead plates and a pillar. Tints each compartment by
## whether it has gravity and keeps the camera on the player without rotating.

const TINT_GRAVITY := Color(1.0, 0.72, 0.4, 0.10)   # warm
const TINT_ZERO_G := Color(0.4, 0.7, 1.0, 0.12)     # cool

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	camera.global_position = player.global_position
	camera.reset_smoothing()

func _process(_delta: float) -> void:
	camera.global_position = player.global_position
	for compartment in [$Left, $Right]:
		var tint: Polygon2D = compartment.get_node("Tint")
		tint.color = TINT_GRAVITY if compartment.has_gravity() else TINT_ZERO_G
