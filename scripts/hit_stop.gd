class_name HitStop extends RefCounted

## A few frames where both parties of a hit freeze: process_mode DISABLED on
## each, then INHERIT on each still alive. Called mid-tick (from the swing
## landing) or from idle, the freeze covers the next `frames` whole ticks.

const FRAMES := 3

static func freeze(tree: SceneTree, nodes: Array, frames: int = FRAMES) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_DISABLED
	# The next physics_frame signal is the start of the first frozen tick;
	# one more than `frames` signals lands at the start of the tick after the last.
	for i in range(frames + 1):
		await tree.physics_frame
	for n in nodes:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_INHERIT
