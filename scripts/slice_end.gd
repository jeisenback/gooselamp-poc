class_name SliceEnd extends Area2D

## The end of the slice: a Player entering it pauses the tree and shows the
## Screen child, with the time since launch.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Screen.visible = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is Player) or $Screen.visible:
		return
	var seconds := Time.get_ticks_msec() / 1000
	$Screen/Time.text = "%d:%02d" % [seconds / 60, seconds % 60]
	$Screen.visible = true
	get_tree().paused = true
