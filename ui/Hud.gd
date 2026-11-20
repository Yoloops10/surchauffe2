extends Control
## HUD du haut (style panneau) : jetons en gros, TABLE n/7, coeurs, barre d'objectif,
## minuterie fine et contrainte. Se met a jour en ecoutant les signaux de Game.

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Balance = preload("res://data/Balance.gd")
const Tables = preload("res://data/Tables.gd")

var _fond: Panel
var _lbl_titre: Label
var _lbl_jetons: Label
var _puce: Panel
var _lbl_table: Label
var _lbl_temps: Label
var _lbl_contr: Label
var _lbl_obj: Label
var _coeurs: Array[TextureRect] = []
var _obj_cadre: Panel
var _obj_fill: ColorRect
var _tps_fond: ColorRect
var _tps: ColorRect
var _acc: float = 0.0
var _pop: Tween = null
var _dernier_pop: int = 0
var _vies_prec: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fond = Pixels.panneau(100, 100, "panel_nuit")
	add_child(_fond)
	_lbl_titre = Pixels.label("JETONS", 8, Pal.GRIS)
	_lbl_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_titre)
	_lbl_jetons = Pixels.label("0", 32, Pal.DORE)
	_lbl_jetons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_jetons)
	_puce = Pixels.panneau(150, 40, "panel_rouge")
	add_child(_puce)
	_lbl_table = Pixels.label("TABLE 1/7", 16, Pal.CREME)
	_lbl_table.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_table)
	_lbl_temps = Pixels.label("", 16, Pal.CREME)
	add_child(_lbl_temps)
	for i in Balance.VIES_DEPART:
		var c: TextureRect = Pixels.rect(Pixels.tex("coeur_plein"))
		_coeurs.append(c)
		add_child(c)
	_obj_cadre = Pixels.panneau(100, 34, "panel", false)
	add_child(_obj_cadre)
	_obj_fill = ColorRect.new()
	_obj_fill.color = Pal.DORE
	_obj_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_obj_fill)
	_lbl_obj = Pixels.label("", 16, Pal.CREME)
	_lbl_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_obj)
	_tps_fond = ColorRect.new()
	_tps_fond.color = Pal.ENCRE
	_tps_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tps_fond)
	_tps = ColorRect.new()
	_tps.color = Pal.VERT
	_tps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tps)
	_lbl_contr = Pixels.label("", 16, Pal.GRIS)
	_lbl_contr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_contr)
	Game.jetons_changed.connect(_on_jetons)
	Game.vies_changed.connect(_on_vies)
	Game.table_demarree.connect(_on_table)
	Game.contrainte_changed.connect(_maj_contrainte)
	resized.connect(_layout)
	_layout()
	_on_jetons(Game.jetons)
	_on_vies(Game.vies)
	_on_table(Game.table_index)

func _layout() -> void:
	var w: float = size.x
	_fond.position = Vector2(8, 6)
	_fond.size = Vector2(w - 16.0, 172)
	_lbl_titre.position = Vector2(0, 16)
	_lbl_titre.size = Vector2(w, 12)
	_lbl_jetons.position = Vector2(0, 28)
	_lbl_jetons.size = Vector2(w, 40)
	_lbl_jetons.pivot_offset = Vector2(w / 2.0, 20.0)
	_puce.position = Vector2(20, 72)
	_lbl_table.position = Vector2(20, 82)
	_lbl_table.size = Vector2(150, 24)
	_lbl_temps.position = Vector2(186, 82)
	var x: float = w - 20.0
	for i in range(_coeurs.size() - 1, -1, -1):
		x -= 28.0
		_coeurs[i].position = Vector2(x, 78)
		_coeurs[i].pivot_offset = _coeurs[i].size / 2.0
		x -= 6.0
	_obj_cadre.position = Vector2(20, 118)
	_obj_cadre.size = Vector2(w - 40.0, 34)
	_lbl_obj.position = Vector2(20, 125)
	_lbl_obj.size = Vector2(w - 40.0, 24)
	_tps_fond.position = Vector2(24, 156)
	_tps_fond.size = Vector2(w - 48.0, 6)
	_lbl_contr.position = Vector2(20, 164)
	_lbl_contr.size = Vector2(w - 40.0, 20)

## Petit « pop » du compteur quand des jetons tombent (limite a ~12 par seconde).
func _on_jetons(j: float) -> void:
	_lbl_jetons.text = Game.fmt_entier(j)
	var t: int = Time.get_ticks_msec()
	if t - _dernier_pop < 80:
		return
	_dernier_pop = t
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_lbl_jetons.scale = Vector2(1.12, 1.12)
	_pop = create_tween()
	_pop.tween_property(_lbl_jetons, "scale", Vector2.ONE, 0.12)

func _on_vies(v: int) -> void:
	for i in _coeurs.size():
		_coeurs[i].texture = Pixels.tex("coeur_plein" if i < v else "coeur_vide")
	if _vies_prec >= 0 and v < _vies_prec and v >= 0 and v < _coeurs.size():
		# le cœur perdu « claque »
		var c: TextureRect = _coeurs[v]
		c.scale = Vector2(1.8, 1.8)
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vies_prec = v

func _on_table(i: int) -> void:
	_lbl_table.text = "TABLE %d/%d" % [i + 1, Tables.nombre()]
	_maj_contrainte()

func _maj_contrainte() -> void:
	var texte: String = Tables.texte_contrainte(Game.table_index)
	var prog: String = Game.contrainte_progression()
	if prog != "":
		texte += " (%s)" % prog
	_lbl_contr.text = texte
	var a_contrainte: bool = str(Tables.obtenir(Game.table_index)["type"]) != "aucune"
	var ok: bool = a_contrainte and Game.contrainte_satisfaite()
	_lbl_contr.add_theme_color_override("font_color", Pal.VERT if ok else Pal.CREME)

func _process(delta: float) -> void:
	var t: Dictionary = Tables.obtenir(Game.table_index)
	# barre d'objectif : jetons / objectif
	var obj: float = maxf(1.0, Game.objectif())
	var fr: float = clampf(Game.jetons / obj, 0.0, 1.0)
	var bw: float = _obj_cadre.size.x - 12.0
	_obj_fill.position = _obj_cadre.position + Vector2(6, 6)
	_obj_fill.size = Vector2(floorf(bw * fr / 2.0) * 2.0, 22)
	_obj_fill.color = Pal.VERT if fr >= 1.0 else Pal.DORE
	_lbl_obj.text = "%s / %s" % [Game.fmt_compact(Game.jetons), Game.fmt_compact(obj)]
	_lbl_obj.add_theme_color_override("font_color", Pal.ENCRE if fr > 0.5 else Pal.CREME)
	_lbl_obj.add_theme_color_override("font_shadow_color", Color(Pal.ENCRE, 0.0 if fr > 0.5 else 1.0))
	# minuterie fine
	var duree: float = maxf(1.0, float(t["duree"]))
	var frac: float = clampf(Game.temps_restant / duree, 0.0, 1.0)
	_tps.position = _tps_fond.position
	_tps.size = Vector2(floorf(_tps_fond.size.x * frac / 2.0) * 2.0, 6)
	var urgent: bool = Game.temps_restant < 10.0
	var coul: Color = Pal.VERT
	if urgent:
		coul = Pal.ROUGE
	elif Game.temps_restant < 30.0:
		coul = Pal.ORANGE
	_tps.color = coul
	_lbl_temps.text = Game.fmt_secondes(Game.temps_restant)
	_lbl_temps.add_theme_color_override("font_color", Pal.ROUGE if urgent and fmod(Game.temps_restant, 1.0) > 0.5 else coul)
	# la progression (fenetre glissante, multiplicateur...) bouge en continu : 5 fois/s suffit
	_acc += delta
	if _acc >= 0.2:
		_acc = 0.0
		_maj_contrainte()
