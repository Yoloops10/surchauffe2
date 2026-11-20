extends Label
## Texte flottant « +12 » : monte, s'efface, se libere tout seul.

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")

## A appeler APRES add_child. centre : position (dans le parent) du milieu du texte.
func lancer(texte: String, centre: Vector2, couleur: Color, taille: int = 16, monte: float = 80.0) -> void:
	text = texte
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Pixels.appliquer_police(self, taille, couleur)
	z_index = 20
	size = get_minimum_size()
	position = Vector2(snappedf(centre.x - size.x / 2.0, 2.0), snappedf(centre.y - size.y / 2.0, 2.0))
	var fin_y: float = snappedf(position.y - monte, 2.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", fin_y, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tw.chain().tween_callback(queue_free)
