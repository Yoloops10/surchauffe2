extends Control
## Fin de run : resume (table atteinte, pic, meilleur jackpot), plombs gagnes, REJOUER / MENU.
## Style : fond tourbillon, titre qui claque, lignes qui apparaissent, compteur de plombs qui defile.

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Balance = preload("res://data/Balance.gd")
const Fond = preload("res://ui/Fond.gd")

var _lbl_relance: Label = null
var _panneau_relance: Panel = null
var _temps_relance: float = 0.0
var _rejouer: Button = null
var _t: float = 0.0

func _ready() -> void:
	Sfx.musique("gameover")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v: Vector2 = get_viewport_rect().size
	var r: Dictionary = Game.dernier_resume
	var victoire: bool = bool(r.get("victoire", false))
	Fond.ajouter(self, Pal.VERT if victoire else Pal.ROUGE, 0.6, 0.7)
	var y: float = snappedf(maxf(50.0, v.y * 0.07), 2.0)
	# titre qui « claque » : grand puis normal
	var titre: Label = _texte(v.x, "NUIT RÉUSSIE !" if victoire else "FIN DE NUIT", 32, Pal.VERT if victoire else Pal.ROUGE, y)
	titre.pivot_offset = Vector2(v.x / 2.0, 20.0)
	titre.scale = Vector2(2.2, 2.2)
	titre.modulate.a = 0.0
	var tw: Tween = titre.create_tween().set_parallel(true)
	tw.tween_property(titre, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(titre, "modulate:a", 1.0, 0.15)
	var sous_titre: String = "La machine a rendu l'âme." if not victoire else "Tu as vidé le casino."
	if bool(r.get("defi", false)):
		sous_titre = "DÉFI DU JOUR : " + ("NOUVEAU RECORD !" if bool(r.get("defi_record", false)) else "SCORE %s" % Game.fmt_compact(float(r.get("pic", 0.0))))
	elif int(r.get("mise", 0)) > 0:
		sous_titre += " (MISE %d)" % (int(r.get("mise", 0)) + 1)
	_texte(v.x, sous_titre, 16, Pal.CREME, y + 56.0)
	y += 110.0
	var pw: float = v.x - 48.0
	var ph: float = 330.0
	var panneau: Panel = Pixels.panneau(pw, ph, "panel")
	panneau.position = Vector2(24, y)
	add_child(panneau)
	_entrer(panneau, 0.1)
	var lignes: Array = [
		["TABLE ATTEINTE", "%d / %d" % [int(r.get("table", 1)), int(r.get("tables_total", 7))]],
		["PIC DE JETONS", Game.fmt_entier(float(r.get("pic", 0.0)))],
		["MEILLEUR JACKPOT", Game.fmt_entier(float(r.get("meilleur_jackpot", 0.0)))],
	]
	var ly: float = y + 26.0
	var delai: float = 0.3
	for l: Array in lignes:
		var a: Label = Pixels.label(str(l[0]), 16, Pal.CREME)
		a.position = Vector2(48, ly)
		add_child(a)
		var b: Label = Pixels.label(str(l[1]), 16, Pal.DORE)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.position = Vector2(v.x - 48.0 - 260.0, ly)
		b.size = Vector2(260, 20)
		add_child(b)
		_entrer(a, delai)
		_entrer(b, delai)
		ly += 44.0
		delai += 0.15
	# separateur
	var sep: ColorRect = ColorRect.new()
	sep.color = Pal.GRIS
	sep.position = Vector2(48, ly + 2.0)
	sep.size = Vector2(pw - 48.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)
	# plombs gagnes : le compteur defile de 0 a N (effet « caisse »)
	var gagnes: int = int(r.get("plombs_gagnes", 0))
	var lbl_gain: Label = _texte(v.x, "PLOMBS GAGNÉS : +0", 32, Pal.ORANGE, ly + 18.0)
	lbl_gain.pivot_offset = Vector2(v.x / 2.0, 20.0)
	var tc: Tween = create_tween()
	tc.tween_interval(0.9)
	tc.tween_method(func(n: float) -> void:
		lbl_gain.text = "PLOMBS GAGNÉS : +%d" % int(n)
		lbl_gain.scale = Vector2(1.08, 1.08) if int(n) != gagnes else Vector2.ONE, 0.0, float(gagnes), 0.8)
	tc.tween_callback(func() -> void:
		Sfx.jouer("table")
		lbl_gain.scale = Vector2(1.25, 1.25)
		lbl_gain.create_tween().tween_property(lbl_gain, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	_texte(v.x, "TOTAL : %d" % int(r.get("plombs_total", Save.plombs)), 16, Pal.CREME, ly + 66.0)
	var manque: float = float(r.get("manque", 0.0))
	if not victoire and manque > 0.0:
		var obj: float = maxf(1.0, float(r.get("objectif", 1.0)))
		var pct: int = int(floorf(100.0 * float(r.get("jetons_fin", 0.0)) / obj))
		_texte(v.x, "IL TE MANQUAIT %s JETONS !" % Game.fmt_compact(manque), 16, Pal.ROUGE, ly + 100.0)
		_texte(v.x, "%d %% DE L'OBJECTIF... SI PRÈS !" % pct, 16, Pal.ORANGE, ly + 124.0)
	if bool(r.get("bonus_relance", false)):
		_texte(v.x, "BONUS RELANCE APPLIQUÉ ×1,5", 16, Pal.VERT, ly + 148.0)
	var yb: float = maxf(y + ph + 82.0, v.y - 250.0)
	# --- offre de relance : bandeau rouge qui pulse -------------------------------------------
	if not victoire:
		_temps_relance = Balance.RELANCE_DELAI_S
		_panneau_relance = Pixels.panneau(pw, 44, "panel_rouge")
		_panneau_relance.position = Vector2(24, yb - 60.0)
		add_child(_panneau_relance)
		_lbl_relance = Pixels.label("", 16, Pal.CREME)
		_lbl_relance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_relance.position = Vector2(24, yb - 48.0)
		_lbl_relance.size = Vector2(pw, 24)
		add_child(_lbl_relance)
	_rejouer = Pixels.bouton("REJOUER", 32, 360, 88, "vert")
	_rejouer.position = Vector2(snappedf((v.x - 360.0) / 2.0, 2.0), yb)
	_rejouer.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		Game.nouvelle_run()
		if not victoire and _temps_relance > 0.0:
			Game.relance_active = true   # rejoue vite : plombs x1,5 a la fin de la prochaine run
		Fx.aller("res://scenes/Run.tscn"))
	add_child(_rejouer)
	var menu: Button = Pixels.bouton("ABANDONNER" if not victoire else "MENU", 16, 240, 56, "prune")
	menu.position = Vector2(snappedf((v.x - 240.0) / 2.0, 2.0), yb + 108.0)
	menu.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		Fx.aller("res://scenes/Menu.tscn"))
	add_child(menu)
	if victoire:
		Sfx.jouer("jackpot")
	# --- bandeaux : mise debloquee, succes, boss (un par un, en haut de l'ecran) ---------------
	var bandeaux: Array = []
	if int(r.get("mise_debloquee", -1)) >= 0:
		var m: Dictionary = Balance.MISES[int(r["mise_debloquee"])]
		bandeaux.append(["%s DÉBLOQUÉE !" % str(m["nom"]), "%s PLOMBS ×%s" % [str(m["malus"]).to_upper(), str(m["plombs"]).replace(".", ",")]])
	for sc: Dictionary in r.get("succes", []):
		bandeaux.append(["SUCCÈS : " + str(sc["nom"]), "%s  +%d PLOMBS" % [str(sc["desc"]).to_upper(), int(sc["plombs"])]])
	if int(r.get("bosses", 0)) > 0:
		bandeaux.append(["BOSS VAINCUS : %d" % int(r["bosses"]), "+%d PLOMBS CHACUN" % Balance.BOSS_PLOMBS])
	if bool(r.get("defi", false)) and int(r.get("defi_bonus", 0)) > 0:
		bandeaux.append(["DÉFI DU JOUR RELEVÉ", "+%d PLOMBS (1RE FOIS)" % int(r["defi_bonus"])])
	for i in bandeaux.size():
		_bandeau(str(bandeaux[i][0]), str(bandeaux[i][1]), 1.2 + 2.6 * float(i))

## Bandeau doré qui descend du haut, reste 2 s puis remonte.
func _bandeau(titre: String, sous: String, delai: float) -> void:
	var w: float = get_viewport_rect().size.x - 32.0
	var p: Panel = Pixels.panneau(w, 60.0, "panel_or")
	p.position = Vector2(16, -80)
	p.z_index = 40
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: Label = Pixels.label(titre, 16, Pal.DORE)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.position = Vector2(0, 10)
	a.size = Vector2(w, 20)
	p.add_child(a)
	var b: Label = Pixels.label(sous, 8, Pal.CREME)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.position = Vector2(0, 38)
	b.size = Vector2(w, 12)
	p.add_child(b)
	add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(delai)
	tw.tween_callback(func() -> void: Sfx.jouer("table", 1.2))
	tw.tween_property(p, "position:y", 6.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(p, "position:y", -80.0, 0.25)
	tw.tween_callback(p.queue_free)

## Apparition : glisse de 20 px vers le haut en fondu, apres un delai.
func _entrer(n: Control, delai: float) -> void:
	var cible: float = n.position.y
	n.position.y = cible + 20.0
	n.modulate.a = 0.0
	var tw: Tween = n.create_tween().set_parallel(true)
	tw.tween_property(n, "position:y", cible, 0.3).set_delay(delai).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(delai)

func _process(delta: float) -> void:
	_t += delta
	if _rejouer != null:
		# le gros bouton « respire » pour inciter a relancer
		var k: float = 1.0 + 0.015 * sin(_t * 5.0)
		_rejouer.pivot_offset = _rejouer.size / 2.0
		_rejouer.scale = Vector2(k, k)
	if _lbl_relance == null:
		return
	_temps_relance = maxf(0.0, _temps_relance - delta)
	if _temps_relance > 0.0:
		_lbl_relance.text = "REJOUE EN %d s : PLOMBS ×1,5 !" % int(ceilf(_temps_relance))
		_panneau_relance.modulate = Color(1, 1, 1, 1) if fmod(_temps_relance, 1.0) > 0.5 else Color(1.25, 1.1, 1.1, 1)
	else:
		_lbl_relance.text = "BONUS PERDU..."
		_panneau_relance.modulate = Color(0.55, 0.55, 0.6, 1)

func _texte(w: float, t: String, taille: int, couleur: Color, y: float) -> Label:
	var l: Label = Pixels.label(t, taille, couleur)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(w, float(taille) * 1.4)
	add_child(l)
	return l
