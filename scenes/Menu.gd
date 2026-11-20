extends Control
## Menu principal + vue MACHINES (12 vignettes, plombs, achat) + effacement de la sauvegarde
## avec double confirmation. Tout est construit en code (style : fond tourbillon, boutons 3D).

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Fond = preload("res://ui/Fond.gd")
const Machines = preload("res://data/Machines.gd")
const Tables = preload("res://data/Tables.gd")
const Balance = preload("res://data/Balance.gd")
const Succes = preload("res://data/Succes.gd")

const SYMS: Array[String] = ["cerise", "citron", "cloche", "sept", "jackpot"]

var _w: float = 540.0
var _h: float = 960.0
var _mode: String = "principal"      # principal | machines
var _selection: String = ""          # machine selectionnee dans la vue MACHINES
var _btn_mute: Button = null
var _lbl_serie: Label = null         # compte a rebours avant la perte de la serie
var _btn_offre: Button = null        # offre flash (compte a rebours)
var _lbl_detail_offre: Label = null  # rappel de l'offre dans la fiche machine
var _titre: Control = null
var _titre_y: float = 0.0
var _reels: Array[TextureRect] = []
var _deco: Array[TextureRect] = []
var _deco_p: Array[Vector3] = []     # phase, vitesse, x de base
var _t: float = 0.0
var _t_reel: float = 0.0
var _cartes: Array[Panel] = []
var _carte_p: Array[Vector3] = []   # x, y de base, rotation de base (degres)
var _saut: Dictionary = {}
var _intro_faite: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_construire)
	Sfx.musique("menu")
	_construire()
	_proposer_bonus_quotidien()

## Une seule fois par lancement : bonus du jour + serie en jeu (aversion a la perte).
func _proposer_bonus_quotidien() -> void:
	if Game.serie_proposee:
		return
	Game.serie_proposee = true
	var a: Dictionary = Save.apercu_serie()
	if a.is_empty():
		return
	var texte: String = "SÉRIE : %d jour%s. +%d plombs à réclamer. Reviens demain, sinon ta série repart de zéro !" % [
		int(a["serie"]), "s" if int(a["serie"]) > 1 else "", int(a["recompense"])]
	if int(a["perdue"]) > 0:
		texte = "Tu as perdu ta série de %d jours. Recommence : +%d plombs aujourd'hui." % [int(a["perdue"]), int(a["recompense"])]
	_modal("BONUS DU JOUR", texte, "RÉCLAMER +%d" % int(a["recompense"]), func() -> void:
		Sfx.jouer("jackpot")
		Save.reclamer_serie()
		_construire(), "NON, JE RENONCE")

func _process(delta: float) -> void:
	_t += delta
	if _lbl_serie != null and is_instance_valid(_lbl_serie):
		if Save.serie > 0 or Save.serie_active_aujourdhui():
			_lbl_serie.text = "SÉRIE %d J | PERTE DANS %s" % [Save.serie, _hms(Save.secondes_avant_perte())]
		else:
			_lbl_serie.text = "SÉRIE 0 J | RÉCLAME TON BONUS !"
	var o: Dictionary = Save.offre_flash()
	if _btn_offre != null and is_instance_valid(_btn_offre) and not o.is_empty():
		_btn_offre.text = "OFFRE FLASH -%d %% : %s\n%s" % [
			int(round(float(o["remise"]) * 100.0)), str(Machines.obtenir(str(o["id"])).get("nom", "")), _hms(float(o["reste"]))]
		# pulsation : le bouton « respire » pour attirer l'oeil
		var k: float = 1.0 + 0.02 * sin(_t * 5.0)
		_btn_offre.pivot_offset = _btn_offre.size / 2.0
		_btn_offre.scale = Vector2(k, k)
	if _lbl_detail_offre != null and is_instance_valid(_lbl_detail_offre) and not o.is_empty():
		_lbl_detail_offre.text = "OFFRE FLASH : IL RESTE %s !" % _hms(float(o["reste"]))
	# logo : balancement doux
	if _titre != null and is_instance_valid(_titre):
		_titre.pivot_offset = _titre.size / 2.0
		_titre.rotation = deg_to_rad(2.2 * sin(_t * 1.6))
		_titre.position.y = _titre_y + 5.0 * sin(_t * 2.2)
	# cartes : flottement et balancement (la carte du milieu bouge le moins)
	for i in _cartes.size():
		var c: Panel = _cartes[i]
		if not is_instance_valid(c):
			continue
		var p: Vector3 = _carte_p[i]
		c.rotation = deg_to_rad(p.z + 2.0 * sin(_t * 1.5 + float(i) * 2.0))
		if _t > 1.2:
			c.position.y = p.y + 6.0 * sin(_t * 1.9 + float(i) * 1.7)
	# mini-rouleaux : un symbole change toutes les 0,55 s, avec un petit rebond
	if not _reels.is_empty():
		_t_reel += delta
		if _t_reel >= 0.55:
			_t_reel = 0.0
			for i in _reels.size():
				if is_instance_valid(_reels[i]):
					_reels[i].texture = Pixels.tex("sym_" + SYMS.pick_random())
					_reels[i].position.y += 10.0
					var tw: Tween = _reels[i].create_tween()
					tw.tween_property(_reels[i], "position:y", _reels[i].position.y - 10.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# symboles qui flottent dans le fond
	for i in _deco.size():
		var d: TextureRect = _deco[i]
		if not is_instance_valid(d):
			continue
		var p: Vector3 = _deco_p[i]
		var y: float = fposmod(_h + 80.0 - (_t * p.y * 28.0 + p.x * 300.0), _h + 160.0) - 80.0
		d.position = Vector2(p.z + 30.0 * sin(_t * 0.7 + p.x * 6.0), y)
		d.rotation = deg_to_rad(18.0 * sin(_t * 0.5 + p.x * 9.0))

func _hms(s: float) -> String:
	var t: int = int(maxf(0.0, s))
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _vider() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()

func _construire() -> void:
	_vider()
	_lbl_serie = null
	_btn_offre = null
	_lbl_detail_offre = null
	_titre = null
	_reels.clear()
	_cartes.clear()
	_carte_p.clear()
	_deco.clear()
	_deco_p.clear()
	var v: Vector2 = get_viewport_rect().size
	_w = v.x
	_h = v.y
	Fond.ajouter(self, Pal.ROUGE if _mode == "principal" else Pal.GRIS, 0.85 if _mode == "principal" else 0.5, 1.0)
	if _mode == "machines":
		_vue_machines()
	elif _mode == "succes":
		_vue_succes()
	else:
		_vue_principale()

## Etiquette centree sur toute la largeur.
func _texte(t: String, taille: int, couleur: Color, y: float) -> Label:
	var l: Label = Pixels.label(t, taille, couleur)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(_w, float(taille) * 1.6)
	add_child(l)
	return l

func _bouton_centre(t: String, taille: int, w: float, h: float, y: float, schema: String = "orange") -> Button:
	var b: Button = Pixels.bouton(t, taille, w, h, schema)
	b.position = Vector2(snappedf((_w - w) / 2.0, 2.0), y)
	add_child(b)
	return b

## Pastille « jauge » : petit titre + valeur dans un cadre sombre.
func _pastille(titre: String, valeur: String, x: float, y: float, w: float, coul: Color) -> void:
	var p: Panel = Pixels.panneau(w, 64, "panel_nuit")
	p.position = Vector2(x, y)
	add_child(p)
	var a: Label = Pixels.label(titre, 8, Pal.GRIS)
	a.position = Vector2(x + 14, y + 10)
	add_child(a)
	var b: Label = Pixels.label(valeur, 16, coul)
	b.position = Vector2(x + 14, y + 28)
	add_child(b)

# ---------------------------------------------------------------------------
# Vue principale
# ---------------------------------------------------------------------------

func _decor() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for i in 7:
		var d: TextureRect = Pixels.rect(Pixels.tex("sym_" + SYMS[i % SYMS.size()]))
		d.modulate = Color(1, 1, 1, 0.22)
		d.pivot_offset = d.size / 2.0
		add_child(d)
		_deco.append(d)
		_deco_p.append(Vector3(rng.randf(), 0.6 + rng.randf() * 0.9, rng.randf() * (_w - 64.0)))

func _vue_principale() -> void:
	_decor()
	# --- barre du haut : plombs + son -------------------------------------------------
	_pastille("PLOMBS", Game.fmt_entier(float(Save.plombs)), 16, 14, 200, Pal.DORE)
	_btn_mute = Pixels.bouton("SON" if not Save.mute else "MUET", 16, 104, 56, "prune")
	_btn_mute.position = Vector2(_w - 120.0, 18)
	_btn_mute.pressed.connect(_basculer_mute)
	add_child(_btn_mute)
	# --- logo (oscille comme celui de Balatro) ------------------------------------------
	var ty: float = snappedf(_h * 0.105, 2.0)
	_titre_y = ty
	var ombre: TextureRect = Pixels.rect(Pixels.tex("titre"))
	ombre.modulate = Color(Pal.ENCRE, 0.7)
	ombre.position = Vector2(snappedf((_w - ombre.size.x) / 2.0, 2.0) + 6.0, ty + 10.0)
	add_child(ombre)
	var titre: TextureRect = Pixels.rect(Pixels.tex("titre"))
	titre.position = Vector2(snappedf((_w - titre.size.x) / 2.0, 2.0), ty)
	add_child(titre)
	_titre = titre
	_texte("CASINO-CLICKER ROGUELITE", 16, Pal.CREME, ty + titre.size.y + 22.0)
	# --- main de 3 cartes en eventail (comme la pile de cartes du menu de Balatro) --------
	_main_cartes(snappedf(_h * 0.255, 2.0))
	# --- pastilles de progression ------------------------------------------------------------
	var nom_machine: String = "DE BASE"
	if Save.machine_active != "":
		nom_machine = str(Machines.obtenir(Save.machine_active).get("nom", "DE BASE"))
	var py: float = snappedf(_h * 0.255, 2.0) + 178.0
	var pw: float = (_w - 48.0) / 2.0
	_pastille("MEILLEURE TABLE", "%d / %d" % [Save.meilleure_table, Tables.nombre()], 16, py, pw, Pal.CREME)
	_pastille("MACHINE", nom_machine, 32.0 + pw, py, pw, Pal.VERT)
	# --- retention : serie + offre flash --------------------------------------------------------
	var ry: float = py + 78.0
	var rub: Panel = Pixels.panneau(_w - 32.0, 44, "panel_or")
	rub.position = Vector2(16, ry)
	add_child(rub)
	_lbl_serie = Pixels.label("", 16, Pal.DORE)
	_lbl_serie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_serie.position = Vector2(16, ry + 12.0)
	_lbl_serie.size = Vector2(_w - 32.0, 24)
	add_child(_lbl_serie)
	var offre: Dictionary = Save.offre_flash()
	var by: float = ry + 56.0
	if not offre.is_empty():
		_btn_offre = Pixels.bouton("", 16, _w - 32.0, 64, "rouge")
		_btn_offre.position = Vector2(16, by)
		_btn_offre.pressed.connect(func() -> void:
			Sfx.jouer("tap")
			_mode = "machines"
			_selection = str(offre["id"])
			_construire())
		add_child(_btn_offre)
		by += 76.0
	# --- « dock » de boutons façon Balatro : JOUER géant, puis MACHINES | MODE ------------------
	var yb: float = maxf(by + 18.0, _h * 0.67)
	var dock: Panel = Pixels.panneau(_w - 32.0, 254.0, "panel_nuit")
	dock.position = Vector2(16, yb - 14.0)
	add_child(dock)
	var jouer: Button = _bouton_centre("JOUER", 32, _w - 64.0, 88, yb, "vert")
	jouer.pressed.connect(_jouer)
	var rw: float = (_w - 64.0 - 8.0) / 2.0
	var ry2: float = yb + 100.0
	var mach: Button = Pixels.bouton("MACHINES", 16, rw, 60, "orange")
	mach.position = Vector2(32, ry2)
	mach.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		_mode = "machines"
		_selection = Save.machine_active if Save.machine_active != "" else str(Machines.LISTE[0]["id"])
		_construire())
	add_child(mach)
	var arcade: bool = Save.mode == "arcade"
	var bm: Button = Pixels.bouton("MODE : ARCADE" if arcade else "MODE : CLASSIQUE", 16 if arcade else 8, rw, 60, "rouge" if arcade else "prune")
	bm.position = Vector2(32.0 + rw + 8.0, ry2)
	bm.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		Save.set_mode("classique" if arcade else "arcade")
		_construire())
	add_child(bm)
	# --- 3e rangee : MISE (niveau de difficulte) | SUCCES | DEFI DU JOUR -----------------------
	var y3: float = ry2 + 68.0
	var tw3: float = (_w - 64.0 - 16.0) / 3.0
	var bmise: Button = Pixels.bouton("MISE %d" % (Save.mise + 1), 16, tw3, 52, "or" if Save.mise > 0 else "prune")
	bmise.position = Vector2(32, y3)
	bmise.pressed.connect(_changer_mise)
	add_child(bmise)
	var bsucc: Button = Pixels.bouton("SUCCÈS", 16, tw3, 52, "prune")
	bsucc.position = Vector2(32.0 + tw3 + 8.0, y3)
	bsucc.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		_mode = "succes"
		_construire())
	add_child(bsucc)
	var fait: bool = Save.defi_joue_aujourdhui()
	var bdefi: Button = Pixels.bouton("DÉFI" if fait else "DÉFI !", 16, tw3, 52, "prune" if fait else "rouge")
	bdefi.position = Vector2(32.0 + 2.0 * (tw3 + 8.0), y3)
	bdefi.pressed.connect(_defi_du_jour)
	add_child(bdefi)
	var ms: Dictionary = Balance.MISES[Save.mise]
	_texte("%s : %s PLOMBS ×%s" % [str(ms["nom"]), str(ms["malus"]).to_upper(), _fmt_x(float(ms["plombs"]))], 8, Pal.CREME, y3 + 62.0)
	var eff: Button = _bouton_centre("EFFACER LA SAUVEGARDE", 8, 260, 40, _h - 48.0, "prune")
	eff.pressed.connect(_effacer_etape1)

## Trois cartes crème penchées, qui flottent et sautent quand on les touche.
func _main_cartes(y0: float) -> void:
	var cw: float = 116.0
	var ch: float = 160.0
	var noms: Array[String] = ["cerise", "sept", "jackpot"]
	var coins: Array[String] = ["A", "7", "$"]
	var rots: Array[float] = [-11.0, 0.0, 11.0]
	for i in 3:
		var c: Panel = Pixels.panneau(cw, ch, "panel_clair")
		c.pivot_offset = Vector2(cw, ch) / 2.0
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var base: Vector2 = Vector2(_w / 2.0 - cw / 2.0 + (float(i) - 1.0) * 96.0, y0 + (0.0 if i == 1 else 14.0))
		var sym: TextureRect = Pixels.rect(Pixels.tex("sym_" + noms[i]))
		sym.position = Vector2(snappedf((cw - sym.size.x) / 2.0, 2.0), snappedf((ch - sym.size.y) / 2.0, 2.0))
		sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(sym)
		for coin: Vector2 in [Vector2(10, 8), Vector2(cw - 26.0, ch - 24.0)]:
			var l: Label = Pixels.label(coins[i], 16, Pal.ROUGE, false)
			l.position = coin
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(l)
		c.z_index = 2 if i == 1 else 1
		c.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_sauter(c, i))
		add_child(c)
		_cartes.append(c)
		_carte_p.append(Vector3(base.x, base.y, rots[i]))
		# entree : tombe du haut avec rebond (une seule fois par ouverture du menu)
		if not _intro_faite:
			c.position = Vector2(base.x, -240.0)
			c.create_tween().tween_property(c, "position:y", base.y, 0.55).set_delay(0.12 * float(i)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			c.position = base
	_intro_faite = true

func _sauter(c: Panel, i: int) -> void:
	Sfx.jouer("tap", 0.9 + 0.2 * float(i))
	_saut[c] = 0.0
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fmt_x(x: float) -> String:
	var t: String = ("%.2f" % x).replace(".", ",")
	while t.ends_with("0") and t.contains(","):
		t = t.substr(0, t.length() - 1)
	return t.trim_suffix(",")

## Passe a la mise suivante deja debloquee (ou explique comment debloquer la suivante).
func _changer_mise() -> void:
	Sfx.jouer("tap")
	if Save.mise_max == 0:
		_modal("MISE 2 VERROUILLÉE", "Gagne une nuit complète pour débloquer la MISE 2 : plus dur, mais plus de plombs.", "OK", func() -> void: pass, "FERMER")
		return
	Save.set_mise((Save.mise + 1) % (Save.mise_max + 1))
	_construire()

func _defi_du_jour() -> void:
	Sfx.jouer("tap")
	var m: Dictionary = Save.defi_modificateur()
	var texte: String = "%s : %s Même graine pour tout le monde, machine de base." % [str(m["nom"]), str(m["desc"])]
	if Save.defi_joue_aujourdhui():
		texte += " RECORD : %s" % Game.fmt_compact(Save.defi_score)
	else:
		texte += " 1re fois : +%d plombs !" % Balance.DEFI_PLOMBS_PREMIER
	_modal("DÉFI DU JOUR", texte, "LANCER", func() -> void:
		Game.nouvelle_run(true)
		Fx.aller("res://scenes/Run.tscn"), "PLUS TARD")

func _jouer() -> void:
	Sfx.jouer("tap")
	Game.nouvelle_run()
	Fx.aller("res://scenes/Run.tscn")

func _basculer_mute() -> void:
	Save.set_mute(not Save.mute)
	_btn_mute.text = "MUET" if Save.mute else "SON"
	Sfx.jouer("tap")

# ---------------------------------------------------------------------------
# Fenetres modales : effacement de la sauvegarde (DEUX confirmations), bonus du jour
# ---------------------------------------------------------------------------

func _modal(titre: String, texte: String, label_ok: String, action_ok: Callable, label_non: String = "ANNULER") -> void:
	var voile: ColorRect = ColorRect.new()
	voile.color = Color(Pal.ENCRE, 0.8)
	voile.size = Vector2(_w, _h)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP   # bloque les appuis dessous
	add_child(voile)
	var pw: float = _w - 48.0
	var ph: float = 340.0
	var px: float = 24.0
	var py: float = snappedf((_h - ph) / 2.0, 2.0)
	var panneau: Panel = Pixels.panneau(pw, ph, "panel_or")
	panneau.position = Vector2(px, py)
	voile.add_child(panneau)
	var t: Label = Pixels.label(titre, 32, Pal.ROUGE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(px, py + 24.0)
	t.size = Vector2(pw, 44)
	voile.add_child(t)
	var d: Label = Pixels.label(texte, 16, Pal.CREME)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.position = Vector2(px + 24.0, py + 92.0)
	d.size = Vector2(pw - 48.0, 120)
	voile.add_child(d)
	var bw: float = (pw - 60.0) / 2.0
	var non: Button = Pixels.bouton(label_non, 8, bw, 64, "prune")
	non.position = Vector2(px + 20.0, py + ph - 92.0)
	non.pressed.connect(voile.queue_free)
	voile.add_child(non)
	var oui: Button = Pixels.bouton(label_ok, 16, bw, 64, "vert")
	oui.position = Vector2(px + 40.0 + bw, py + ph - 92.0)
	oui.pressed.connect(func() -> void:
		voile.queue_free()
		action_ok.call())
	voile.add_child(oui)
	# apparition « pop »
	panneau.pivot_offset = Vector2(pw, ph) / 2.0
	panneau.scale = Vector2(0.8, 0.8)
	panneau.create_tween().tween_property(panneau, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _effacer_etape1() -> void:
	Sfx.jouer("tap")
	_modal("EFFACER ?", "Tes plombs, tes machines et ton record seront perdus.", "CONTINUER", _effacer_etape2)

func _effacer_etape2() -> void:
	_modal("VRAIMENT ?", "DERNIÈRE CHANCE : cette action est définitive.", "TOUT EFFACER", func() -> void:
		Save.effacer()
		_mode = "principal"
		_construire())

# ---------------------------------------------------------------------------
# Vue MACHINES
# ---------------------------------------------------------------------------

func _vue_machines() -> void:
	_texte("MACHINES", 32, Pal.DORE, 18.0)
	var pl: Panel = Pixels.panneau(220, 44, "panel_nuit")
	pl.position = Vector2(snappedf((_w - 220.0) / 2.0, 2.0), 72.0)
	add_child(pl)
	_texte("PLOMBS : %s" % Game.fmt_entier(float(Save.plombs)), 16, Pal.DORE, 84.0)
	var cols: int = 3
	var cw: float = 160.0
	var chh: float = 132.0
	var gap: float = 10.0
	var x0: float = snappedf((_w - cols * cw - (cols - 1) * gap) / 2.0, 2.0)
	var y0: float = 130.0
	for i in Machines.LISTE.size():
		var m: Dictionary = Machines.LISTE[i]
		var id: String = m["id"]
		var cx: float = x0 + float(i % cols) * (cw + gap)
		var cy: float = y0 + float(i / cols) * (chh + gap)
		var sel: bool = id == _selection
		var b: Button = Pixels.bouton("", 16, cw, chh, "or" if sel else "prune")
		b.position = Vector2(cx, cy)
		var cle: String = "mach_%d" % i if bool(m["ok"]) else "mach_lock"
		var icone: TextureRect = Pixels.rect(Pixels.tex(cle))
		icone.position = Vector2(snappedf((cw - icone.size.x) / 2.0, 2.0), 10.0)
		b.add_child(icone)
		var c_nom: Color = Pal.ENCRE if sel else Pal.CREME
		var nom: Label = Pixels.label(str(m["nom"]), 8, c_nom, not sel)
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nom.position = Vector2(4, 72)
		nom.size = Vector2(cw - 8.0, 24)
		b.add_child(nom)
		var etat: String = str(Save.prix_machine(id))
		var of: Dictionary = Save.offre_flash()
		var flash: bool = not of.is_empty() and of["id"] == id
		if flash:
			etat += " -%d%%" % int(round(float(of["remise"]) * 100.0))
		var coul: Color = Pal.GRIS
		if not bool(m["ok"]):
			etat = "À VENIR"
		elif Save.machine_active == id:
			etat = "ÉQUIPÉE"
			coul = Pal.VERT
		elif Save.possede(id):
			etat = "ACHETÉE"
			coul = Pal.VERT
		else:
			coul = Pal.DORE if Save.plombs >= Save.prix_machine(id) else Pal.GRIS
			if flash:
				coul = Pal.ORANGE
		if sel:
			coul = Pal.ENCRE
		var lbl_etat: Label = Pixels.label(etat, 16, coul, not sel)
		lbl_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_etat.position = Vector2(4, chh - 38.0)
		lbl_etat.size = Vector2(cw - 8.0, 20)
		b.add_child(lbl_etat)
		b.pressed.connect(func() -> void:
			Sfx.jouer("tap")
			_selection = id
			_construire())
		add_child(b)
	_detail_machine(y0 + 4.0 * (chh + gap) + 8.0)
	var retour: Button = Pixels.bouton("RETOUR", 16, 200, 60, "prune")
	retour.position = Vector2(snappedf((_w - 200.0) / 2.0, 2.0), _h - 76.0)
	retour.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		_mode = "principal"
		_construire())
	add_child(retour)

func _detail_machine(y: float) -> void:
	var m: Dictionary = Machines.obtenir(_selection)
	if m.is_empty():
		return
	var id: String = m["id"]
	var pw: float = _w - 32.0
	var ph: float = _h - y - 92.0
	var panneau: Panel = Pixels.panneau(pw, ph, "panel_or")
	panneau.position = Vector2(16, y)
	add_child(panneau)
	var nom: Label = Pixels.label(str(m["nom"]), 16, Pal.ORANGE)
	nom.position = Vector2(30, y + 14.0)
	add_child(nom)
	var desc: Label = Pixels.label(str(m["desc"]), 16, Pal.CREME)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(30, y + 44.0)
	desc.size = Vector2(pw - 28.0, 60)
	add_child(desc)
	var texte_btn: String = ""
	var actif: bool = true
	var action: Callable = Callable()
	var schema: String = "orange"
	if not bool(m["ok"]):
		texte_btn = "À VENIR"
		actif = false
	elif Save.machine_active == id:
		texte_btn = "DÉSÉQUIPER"
		schema = "prune"
		action = func() -> void: Save.equiper("")
	elif Save.possede(id):
		texte_btn = "ÉQUIPER"
		schema = "vert"
		action = func() -> void: Save.equiper(id)
	else:
		var prix: int = Save.prix_machine(id)
		texte_btn = "ACHETER  %d" % prix
		actif = Save.plombs >= prix
		schema = "or"
		action = func() -> void: Save.acheter(id)
		var of: Dictionary = Save.offre_flash()
		if not of.is_empty() and of["id"] == id:
			_lbl_detail_offre = Pixels.label("", 8, Pal.ORANGE)
			_lbl_detail_offre.position = Vector2(30, y + 112.0)
			add_child(_lbl_detail_offre)
	var b: Button = Pixels.bouton(texte_btn, 16, 250, 60, schema)
	b.position = Vector2(pw - 250.0 + 6.0, y + ph - 76.0)
	b.disabled = not actif
	if actif:
		b.pressed.connect(func() -> void:
			Sfx.jouer("table")
			action.call()
			_construire())
	add_child(b)

# ---------------------------------------------------------------------------
# Vue SUCCES + statistiques
# ---------------------------------------------------------------------------

func _vue_succes() -> void:
	_texte("SUCCÈS", 32, Pal.DORE, 18.0)
	var n_ok: int = Save.succes.size()
	_texte("%d / %d DÉBLOQUÉS" % [n_ok, Succes.LISTE.size()], 16, Pal.CREME, 66.0)
	# statistiques
	var st: Panel = Pixels.panneau(_w - 32.0, 92.0, "panel_nuit")
	st.position = Vector2(16, 98)
	add_child(st)
	var lignes: Array = [
		["PARTIES", str(Save.stat("runs")), "VICTOIRES", str(Save.stat("victoires"))],
		["TAPS", Game.fmt_compact(float(Save.stat("taps"))), "JACKPOTS", str(Save.stat("jackpots"))],
		["BOSS VAINCUS", str(Save.stat("bosses")), "DÉFIS FAITS", str(Save.defis_total)],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		var yy: float = 108.0 + float(i) * 26.0
		for k in 2:
			var a: Label = Pixels.label(str(l[k * 2]), 8, Pal.GRIS)
			a.position = Vector2(32.0 + float(k) * 252.0, yy + 6.0)
			add_child(a)
			var b: Label = Pixels.label(str(l[k * 2 + 1]), 16, Pal.DORE)
			b.position = Vector2(32.0 + float(k) * 252.0 + 130.0, yy)
			add_child(b)
	# liste defilante
	var sc: ScrollContainer = ScrollContainer.new()
	sc.position = Vector2(16, 202)
	sc.size = Vector2(_w - 32.0, _h - 202.0 - 88.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(sc)
	var col: Control = Control.new()
	var rh: float = 72.0
	col.custom_minimum_size = Vector2(_w - 32.0, float(Succes.LISTE.size()) * (rh + 6.0))
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(col)
	for i in Succes.LISTE.size():
		var d: Dictionary = Succes.LISTE[i]
		var ok: bool = Save.succes.has(str(d["id"]))
		var pn: Panel = Pixels.panneau(_w - 32.0, rh, "panel_vert" if ok else "panel_nuit")
		pn.position = Vector2(0, float(i) * (rh + 6.0))
		pn.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(pn)
		var nom: Label = Pixels.label(str(d["nom"]), 16, Pal.ENCRE if ok else Pal.CREME, not ok)
		nom.position = Vector2(16, 10)
		pn.add_child(nom)
		var desc: Label = Pixels.label(str(d["desc"]), 8, Pal.ENCRE if ok else Pal.GRIS, false)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.position = Vector2(16, 40)
		desc.size = Vector2(_w - 32.0 - 120.0, 28)
		pn.add_child(desc)
		var rec: Label = Pixels.label(("OK +%d" if ok else "+%d") % int(d["plombs"]), 16, Pal.ENCRE if ok else Pal.DORE, not ok)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rec.position = Vector2(_w - 32.0 - 112.0, 10)
		rec.size = Vector2(96, 20)
		pn.add_child(rec)
	var retour: Button = Pixels.bouton("RETOUR", 16, 200, 60, "prune")
	retour.position = Vector2(snappedf((_w - 200.0) / 2.0, 2.0), _h - 76.0)
	retour.pressed.connect(func() -> void:
		Sfx.jouer("tap")
		_mode = "principal"
		_construire())
	add_child(retour)
