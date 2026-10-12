class_name Shot extends Area2D

## A projectile. The player's is fast and short-lived: one chip damage and a
## stagger. An enemy's is slow and hurts the player. Any other body it meets
## is a wall. Every contact but the shooter frees it.

const SPEED := 700.0
const LIFETIME := 1.0
const ENEMY_SPEED := 180.0
const ENEMY_LIFETIME := 3.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null            # never hit
var from_player: bool = true

var _life: float = LIFETIME

static func spawn(parent: Node, shooter_node: Node2D, at: Vector2, dir: Vector2, player_shot: bool) -> Shot:
	var shot: Shot = load("res://scenes/Shot.tscn").instantiate()
	shot.shooter = shooter_node
	shot.direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	shot.from_player = player_shot
	shot.rotation = shot.direction.angle()
	shot._life = LIFETIME if player_shot else ENEMY_LIFETIME
	parent.add_child(shot)
	shot.global_position = at # `at` is a world position, whatever the parent's own is
	return shot

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * (SPEED if from_player else ENEMY_SPEED) * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if from_player and body is Enemy:
		body.damage(1, global_position, true)
	elif not from_player and body is Player:
		body.take_hit(global_position)
	queue_free()
