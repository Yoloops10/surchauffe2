extends Control
## Ecran de demarrage : « MADE BY YOLOOPS » (ecriture lettre par lettre), puis le Menu.
## Un appui saute l'intro.

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Fond = preload("res://ui/Fond.gd")

const TEXTE: String = "YOLOOPS"
var _parti: bool = false
var _lbl: Label = null
var _barre: ColorRect = null
var _dernier: int = 0

func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fond: ColorRect = ColorRect.new()
	fond.color = Pal.ENCRE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	Pixels.precharger()
	var v: Vector2 = get_viewport_rect().size
	var cy: float = snappedf(v.y * 0.43, 2.0)
	var haut: Label = Pixels.label("MADE BY", 16, Pal.GRIS)
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	haut.position = Vector2(0, cy - 36.0)
	haut.size = Vector2(v.x, 24)
	haut.modulate.a = 0.0
	add_child(haut)
	haut.create_tween().tween_property(haut, "modulate:a", 1.0, 0.4).set_delay(0.2)
	_lbl = Pixels.label(TEXTE, 32, Pal.DORE)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.position = Vector2(0, cy)
	_lbl.size = Vector2(v.x, 44)
	_lbl.pivot_offset = Vector2(v.x / 2.0, 22.0)
	_lbl.visible_characters = 0
	add_child(_lbl)
	# barre orange qui se remplit sous le nom
	var bw: float = 280.0
	_barre = ColorRect.new()
	_barre.color = Pal.ORANGE
	_barre.position = Vector2(snappedf((v.x - bw) / 2.0, 2.0), cy + 60.0)
	_barre.size = Vector2(0, 6)
	add_child(_barre)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_ecrire, 0.0, float(TEXTE.length()), 0.9).set_delay(0.5)
	tw.tween_property(_barre, "size:x", bw, 0.9).set_delay(0.5)
	var fin: Tween = create_tween()
	fin.tween_interval(1.9)
	fin.tween_callback(func() -> void:
		_lbl.pivot_offset = _lbl.size / 2.0
		_lbl.scale = Vector2(1.15, 1.15)
		_lbl.create_tween().tween_property(_lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	fin.tween_interval(0.8)
	fin.tween_callback(_suite)

func _ecrire(n: float) -> void:
	var k: int = int(n)
	_lbl.visible_characters = k
	if k != _dernier:
		_dernier = k
		Sfx.jouer("tap", 0.8 + 0.1 * float(k))

func _suite() -> void:
	if _parti:
		return
	_parti = true
	Fx.aller("res://scenes/Menu.tscn")

func _input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
		_suite()
