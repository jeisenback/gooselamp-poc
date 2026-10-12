class_name Title extends CanvasLayer

## The game's name and "Press Jump". Pauses the tree while shown; hides on
## the jump action. Shown once per launch.

static var seen: bool = false             # TestHooks resets it to true so scene tests never start paused

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_title() -> void:
	visible = true
	get_tree().paused = true

func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("jump"):
		dismiss()

func dismiss() -> void:
	visible = false
	seen = true
	get_tree().paused = false
