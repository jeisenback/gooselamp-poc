class_name Hud extends CanvasLayer

## Five health pips at the top left, bright in the player colour when lit.

const LIT := Color(0.95, 0.97, 1.0)
const DARK := Color(0.16, 0.17, 0.2)

var _lit: int = Player.MAX_HEALTH

func bind(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health)

func pips_lit() -> int:
	return _lit

func _on_health_changed(health: int) -> void:
	_lit = clampi(health, 0, Player.MAX_HEALTH)
	for i in range(Player.MAX_HEALTH):
		var pip := get_node_or_null("Pips/Pip%d" % (i + 1)) as Polygon2D
		if pip != null:
			pip.color = LIT if i < _lit else DARK
