extends Control
## Choix d'une carte de la maison apres une table reussie : 3 cartes, une seule selection,
## effet immediat. « Le plombier » demande en plus quel symbole retirer de la roue.
## Style : cartes creme qui entrent en rebondissant, legerement penchees, qui se balancent.

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Cards = preload("res://data/Cards.gd")

var _w: float = 540.0
var _h: float = 960.0
var _fini: bool = false
var _boutons: Array[Button] = []
var _base_rot: Array[float] = []
var _t: float = 0.0
var _contenu: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v: Vector2 = get_viewport_rect().size
	_w = v.x
	_h = v.y
	# voile semi-transparent : le fond tourbillon de la table reste visible derriere
	var voile: ColorRect = ColorRect.new()
	voile.color = Color(Pal.ENCRE, 0.82)
	voile.size = v
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)
	_contenu = Control.new()
	_contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contenu)
	_afficher_cartes()

func _process(delta: float) -> void:
	_t += delta
	if _fini:
		return
	for i in _boutons.size():
		if is_instance_valid(_boutons[i]) and _boutons[i].get_meta("pret", false):
			_boutons[i].rotation = deg_to_rad(_base_rot[i] + 0.7 * sin(_t * 1.8 + float(i) * 2.1))

func _titre(texte: String, sous: String, y: float) -> void:
	var t: Label = Pixels.label(texte, 32, Pal.DORE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, y)
	t.size = Vector2(_w, 40)
	_contenu.add_child(t)
	var s: Label = Pixels.label(sous, 16, Pal.CREME)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, y + 48.0)
	s.size = Vector2(_w, 24)
	_contenu.add_child(s)
	# le titre tombe du haut
	for n: Control in [t, s]:
		var cible: float = n.position.y
		n.position.y = cible - 80.0
		n.modulate.a = 0.0
		var tw: Tween = n.create_tween().set_parallel(true)
		tw.tween_property(n, "position:y", cible, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "modulate:a", 1.0, 0.2)

func _afficher_cartes() -> void:
	var ch: float = 168.0
	var gap: float = 16.0
	var n: int = Game.offre.size()
	var total: float = n * ch + (n - 1) * gap
	var y0: float = snappedf(maxf(150.0, (_h - total) / 2.0 + 40.0), 2.0)
	_titre("CHOISIS UNE CARTE", "La maison te propose un marché.", y0 - 118.0)
	var tilts: Array[float] = [-1.6, 1.2, -0.8]
	for i in n:
		var id: String = Game.offre[i]
		var c: Dictionary = Cards.obtenir(id)
		var cw: float = _w - 48.0
		var b: Button = Pixels.bouton("", 16, cw, ch, "prune")
		for nom: String in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(nom, Pixels.style("panel_clair"))
		b.pivot_offset = Vector2(cw, ch) / 2.0
		# vignette d'illustration sur fond sombre
		var cadre: Panel = Pixels.panneau(108, 108, "panel_nuit", false)
		cadre.position = Vector2(18, snappedf((ch - 108.0) / 2.0, 2.0))
		b.add_child(cadre)
		var icone: TextureRect = Pixels.rect(Pixels.tex("ic_" + id))
		icone.position = cadre.position + Vector2(12, 12)
		b.add_child(icone)
		var nom_l: Label = Pixels.label(str(c.get("nom", id)).to_upper(), 16, Pal.ROUGE, false)
		nom_l.position = Vector2(144, 20)
		b.add_child(nom_l)
		var desc: Label = Pixels.label(str(c.get("desc", "")), 16, Pal.ENCRE, false)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.position = Vector2(144, 52)
		desc.size = Vector2(cw - 144.0 - 16.0, ch - 64.0)
		b.add_child(desc)
		b.pressed.connect(func() -> void: _choisir(id, b))
		# entree : glisse depuis la droite avec rebond, une carte apres l'autre
		var cible: Vector2 = Vector2(24, y0 + float(i) * (ch + gap))
		b.position = cible + Vector2(_w, 0)
		b.rotation = deg_to_rad(8.0)
		_base_rot.append(tilts[i % tilts.size()])
		_contenu.add_child(b)
		_boutons.append(b)
		var tw: Tween = b.create_tween().set_parallel(true)
		tw.tween_property(b, "position", cible, 0.5).set_delay(0.15 + 0.14 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "rotation", deg_to_rad(_base_rot[i]), 0.5).set_delay(0.15 + 0.14 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func() -> void: b.set_meta("pret", true))

func _choisir(id: String, bouton: Button) -> void:
	if _fini:
		return
	_fini = true
	Sfx.jouer("table")
	for b: Button in _boutons:
		b.disabled = true
		if b != bouton:
			b.create_tween().tween_property(b, "modulate", Color(1, 1, 1, 0.25), 0.2)
	# la carte choisie se redresse et « claque »
	bouton.z_index = 5
	var tw: Tween = bouton.create_tween().set_parallel(true)
	tw.tween_property(bouton, "rotation", 0.0, 0.15)
	tw.tween_property(bouton, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if id == "plombier":
		await get_tree().create_timer(0.35).timeout
		_choisir_symbole()
	else:
		_valider(id, "")

## Etape supplementaire du plombier : quel symbole retirer ?
func _choisir_symbole() -> void:
	for c: Node in _contenu.get_children():
		c.queue_free()
	_boutons.clear()
	_base_rot.clear()
	_fini = false
	_titre("RETIRER QUEL SYMBOLE ?", "Définitif pour cette nuit.", 150.0)
	var actifs: Array[String] = Game.symboles_actifs()
	var bw: float = 150.0
	var bh: float = 130.0
	var gap: float = 12.0
	var cols: int = 3
	var x0: float = snappedf((_w - cols * bw - (cols - 1) * gap) / 2.0, 2.0)
	for i in actifs.size():
		var sym: String = actifs[i]
		var b: Button = Pixels.bouton("", 16, bw, bh, "prune")
		b.position = Vector2(x0 + float(i % cols) * (bw + gap), 290.0 + float(i / cols) * (bh + gap))
		var ic: TextureRect = Pixels.rect(Pixels.tex("sym_" + sym))
		ic.position = Vector2(snappedf((bw - ic.size.x) / 2.0, 2.0), snappedf((bh - ic.size.y) / 2.0 - 4.0, 2.0))
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			if _fini:
				return
			_fini = true
			_valider("plombier", sym))
		_contenu.add_child(b)
		_boutons.append(b)
		_base_rot.append(0.0)

func _valider(id: String, symbole: String) -> void:
	if symbole != "":
		Game.retirer_symbole(symbole)
	Game.prendre_carte(id)
	await get_tree().create_timer(0.45).timeout
	Game.table_suivante()
	queue_free()
