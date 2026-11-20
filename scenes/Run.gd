extends Control
## Ecran de jeu. Toute la logique est dans Game (autoload) : ici on affiche, on capte
## le levier tactile, et on reagit aux signaux (tremblement, flash, particules, sons).

const Pal = preload("res://art/Palette.gd")
const Pixels = preload("res://art/Pixels.gd")
const Balance = preload("res://data/Balance.gd")
const Machines = preload("res://data/Machines.gd")
const Tables = preload("res://data/Tables.gd")
const Hud = preload("res://ui/Hud.gd")
const Fond = preload("res://ui/Fond.gd")
const FloatText = preload("res://ui/FloatText.gd")
const HudScene: PackedScene = preload("res://ui/Hud.tscn")
const FloatTextScene: PackedScene = preload("res://ui/FloatText.tscn")
const CardPickScene: PackedScene = preload("res://scenes/CardPick.tscn")

const HUD_H: float = 188.0
# Couleur d'accent du fond par table : de plus en plus « chaud »
const ACCENTS: Array[Color] = [Pal.GRIS, Pal.VERT, Pal.ORANGE, Pal.ROUGE, Pal.ROUGE, Pal.ORANGE, Pal.ROUGE, Pal.ORANGE, Pal.ROUGE, Pal.DORE]
const MACHINE_W: float = 352.0
const MACHINE_H: float = 256.0
const LEVIER_W: float = 140.0
const LEVIER_H: float = 220.0

## Jauge de chauffe verticale 0..max (une barre, ou trois avec la Ruche). Pulse des 80 %.
class Jauge extends Control:
	const Pal = preload("res://art/Palette.gd")
	var valeurs: Array = [0.0]
	var verrous: Array = [0.0]
	var maximum: float = 20.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var n: int = valeurs.size()
		var bw: float = 28.0 if n > 1 else 56.0
		var gap: float = 6.0
		var total: float = bw * float(n) + gap * float(n - 1)
		var x0: float = floorf((size.x - total) / 4.0) * 2.0
		var nseg: int = maxi(1, int(roundf(maximum)))
		var haut: float = size.y
		var seg_h: float = floorf((haut - 12.0) / float(nseg))
		for i in n:
			var x: float = x0 + float(i) * (bw + gap)
			var v: float = float(valeurs[i])
			var bloque: bool = float(verrous[i]) > 0.0
			var bord: Color = Pal.CREME
			if bloque:
				bord = Pal.GRIS
			elif v >= maximum * 0.8 and fmod(_t * 6.0, 1.0) < 0.5:
				bord = Pal.ROUGE   # pulsation
			draw_rect(Rect2(x - 2.0, -2.0, bw + 4.0, haut + 4.0), bord)          # cadre
			draw_rect(Rect2(x, 0.0, bw, haut), Pal.ENCRE)
			for u in nseg:
				var yy: float = haut - 6.0 - float(u + 1) * seg_h
				var ratio: float = float(u + 1) / float(nseg)
				var c: Color = Pal.VERT
				var reflet: Color = Pal.CREME
				if ratio > 0.8:
					c = Pal.ROUGE
					reflet = Pal.ORANGE
				elif ratio > 0.5:
					c = Pal.ORANGE
					reflet = Pal.DORE
				if bloque:
					c = Pal.GRIS
					reflet = Pal.GRIS
				var plein: bool = v >= float(u) + 0.5 and not bloque
				var sh: float = maxf(2.0, seg_h - 2.0)
				if plein:
					draw_rect(Rect2(x + 4.0, yy, bw - 8.0, sh), c)
					draw_rect(Rect2(x + 4.0, yy, bw - 8.0, 2.0), reflet)    # reflet 3D
				else:
					draw_rect(Rect2(x + 4.0, yy, bw - 8.0, sh), Pal.PRUNE)

var _vue: Vector2 = Vector2(540, 960)
var _bas: float = 724.0
var _mx: float = 94.0
var _my: float = 210.0

var racine: Control
var hud: Control
var carcasse: TextureRect
var lbl_enseigne: Label
var lbl_roue: Label
var lbl_msg: Label
var lbl_msg2: Label
var lbl_mult: Label
var lbl_chauffe: Label
var lbl_etat: Label
var reels: Array[TextureRect] = []
var ampoules: Array[TextureRect] = []
var ampoules_off: Array[Vector2] = []
var btn_upg: Array[Button] = []
var btn_carte: Button
var btn_mute: Button
var levier: Control
var levier_spr: TextureRect
var levier_fond: Panel
var jauge: Jauge
var flash: ColorRect
var fond: Control
var _piece: Control = null           # piece d'or en jeu (ou null)
var _piece_t: float = 0.0           # temps restant pour la toucher
var _piece_attente: float = 12.0     # delai avant la prochaine
var _piece_base: Vector2 = Vector2.ZERO
var bandeau: Panel
var ombre_machine: ColorRect

var _ampoule_t: float = 0.0
var _ampoule_phase: int = 0
var _shake: float = 0.0
var _spin_t: float = -1.0
var _spin_res: Array = []
var _spin_chg: Array[float] = [0.0, 0.0, 0.0]
var _ui_acc: float = 0.0
var _msg_tween: Tween = null
var _bulle: Panel = null              # bulle du tutoriel
var _tuto_etape: int = -1            # -1 : pas de tuto, 0..2 : bulle affichee, 99 : fini
var _tuto_t: float = 0.0

# etat du levier tactile
var _appuye: bool = false
var _appui_idx: int = -2
var _appui_ms: int = 0
var _appui_pos: Vector2 = Vector2.ZERO
var _appui_zone: int = 0
var _dernier_tap_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	Sfx.musique("run")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_construire()
	_connecter()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_maj_boutons()
	_reels_repos()
	Game.commencer()

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _construire() -> void:
	fond = Fond.ajouter(self, ACCENTS[0], 0.35, 1.0)
	racine = Control.new()
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)
	# bandeau des commandes (bas) + ombre portee de la machine
	bandeau = Pixels.panneau(100, 100, "panel", false)
	racine.add_child(bandeau)
	ombre_machine = ColorRect.new()
	ombre_machine.color = Color(Pal.ENCRE, 0.55)
	ombre_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(ombre_machine)
	hud = HudScene.instantiate()
	racine.add_child(hud)

	carcasse = Pixels.rect(Pixels.tex("carcasse"))
	racine.add_child(carcasse)
	lbl_enseigne = Pixels.label("SURCHAUFFE", 16, Pal.DORE)
	lbl_enseigne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(lbl_enseigne)
	for i in 3:
		var r: TextureRect = Pixels.rect(Pixels.tex("sym_cerise"))
		reels.append(r)
		racine.add_child(r)
	lbl_roue = Pixels.label("ROUE 0/25", 16, Pal.CREME)
	lbl_roue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(lbl_roue)

	# neons : ampoules le long de l'anneau orange de la carcasse
	var offs: Array[Vector2] = []
	for k in 10:
		offs.append(Vector2(28.0 + 32.0 * float(k), 10.0))
		offs.append(Vector2(28.0 + 32.0 * float(k), 238.0))
	for k in 6:
		offs.append(Vector2(10.0, 56.0 + 32.0 * float(k)))
		offs.append(Vector2(334.0, 56.0 + 32.0 * float(k)))
	for o: Vector2 in offs:
		var a: TextureRect = Pixels.rect(Pixels.tex("ampoule_on"))
		ampoules.append(a)
		ampoules_off.append(o)
		racine.add_child(a)

	lbl_msg = Pixels.label("", 32, Pal.ROUGE)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.modulate.a = 0.0
	lbl_msg.z_index = 10
	racine.add_child(lbl_msg)
	lbl_msg2 = Pixels.label("", 16, Pal.CREME)
	lbl_msg2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg2.modulate.a = 0.0
	lbl_msg2.z_index = 10
	racine.add_child(lbl_msg2)

	# boutons d'upgrade + bouton de carte active
	for i in 3:
		var b: Button = Pixels.bouton("", 16, 160.0, 96.0, "vert")
		var idx: int = i
		b.pressed.connect(func() -> void: _acheter(idx))
		btn_upg.append(b)
		racine.add_child(b)
	btn_carte = Pixels.bouton("", 16, 300.0, 56.0, "or")
	btn_carte.pressed.connect(func() -> void: Game.activer_coup_de_barre())
	racine.add_child(btn_carte)

	# jauge de chauffe (bas gauche)
	jauge = Jauge.new()
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jauge.size = Vector2(96, LEVIER_H)
	racine.add_child(jauge)
	lbl_mult = Pixels.label("×1,00", 32, Pal.VERT)
	lbl_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(lbl_mult)
	lbl_chauffe = Pixels.label("", 16, Pal.CREME)
	lbl_chauffe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(lbl_chauffe)
	lbl_etat = Pixels.label("", 16, Pal.ROUGE)
	lbl_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	racine.add_child(lbl_etat)
	btn_mute = Pixels.bouton("MUET" if Save.mute else "SON", 16, 100.0, 52.0, "prune")
	btn_mute.pressed.connect(func() -> void:
		Save.set_mute(not Save.mute)
		btn_mute.text = "MUET" if Save.mute else "SON")
	racine.add_child(btn_mute)

	# levier tactile (bas droite) : tap court / tap maintenu via gui_input
	levier = Control.new()
	levier.size = Vector2(LEVIER_W, LEVIER_H)
	levier.mouse_filter = Control.MOUSE_FILTER_STOP
	levier.gui_input.connect(_on_levier_input)
	racine.add_child(levier)
	levier_fond = Pixels.panneau(LEVIER_W, LEVIER_H, "panel_or")
	levier.add_child(levier_fond)
	levier_spr = Pixels.rect(Pixels.tex("levier_haut"))
	levier_spr.position = Vector2(snappedf((LEVIER_W - levier_spr.size.x) / 2.0, 2.0), 54.0)
	levier.add_child(levier_spr)
	var haut: Label = Pixels.label("TAPE !", 16, Pal.DORE)
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	haut.position = Vector2(0, 12)
	haut.size = Vector2(LEVIER_W, 20)
	levier.add_child(haut)
	var bas: Label = Pixels.label("LONG = ×3", 16, Pal.CREME)
	bas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bas.position = Vector2(0, LEVIER_H - 30.0)
	bas.size = Vector2(LEVIER_W, 20)
	levier.add_child(bas)
	# reperes de zones (2 zones, 3 avec la Ruche)
	var zones: int = Game.nb_jauges() if Game.machine == "ruche" else 2
	for z in range(1, zones):
		var sep: ColorRect = ColorRect.new()
		sep.color = Pal.GRIS
		sep.size = Vector2(LEVIER_W - 24.0, 2)
		sep.position = Vector2(12, snappedf(LEVIER_H * float(z) / float(zones), 2.0))
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		levier.add_child(sep)
	if Game.machine == "ruche":
		for z in zones:
			var m: Label = Pixels.label(str(z + 1), 16, Pal.GRIS)
			m.position = Vector2(12, LEVIER_H * (float(z) + 0.5) / float(zones) - 10.0)
			levier.add_child(m)

	# flash rouge plein ecran (surchauffe)
	flash = ColorRect.new()
	flash.color = Pal.ROUGE
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 30
	add_child(flash)

func _connecter() -> void:
	Game.tap_effectue.connect(_on_tap)
	Game.surchauffe.connect(_on_surchauffe)
	Game.roue_lancee.connect(_on_roue_lancee)
	Game.roue_resultat.connect(_on_roue_resultat)
	Game.table_demarree.connect(_on_table_demarree)
	Game.table_reussie.connect(_on_table_reussie)
	Game.table_ratee.connect(_on_table_ratee)
	Game.run_terminee.connect(_on_run_terminee)
	Game.upgrades_changed.connect(_maj_boutons)
	Game.coup_de_barre_changed.connect(_maj_boutons)
	Game.bouclier_utilise.connect(_on_bouclier)
	Game.cartes_changed.connect(_maj_boutons)

# ---------------------------------------------------------------------------
# Mise en page (portrait ; la hauteur peut depasser 960 avec aspect = expand)
# ---------------------------------------------------------------------------

func _layout() -> void:
	_vue = get_viewport_rect().size
	var w: float = _vue.x
	var h: float = _vue.y
	hud.position = Vector2.ZERO
	hud.size = Vector2(w, HUD_H)
	_bas = h - 236.0
	var y_carte: float = _bas - 8.0 - 56.0
	var y_upg: float = y_carte - 8.0 - 96.0
	var zone_h: float = y_upg - HUD_H
	_my = snappedf(HUD_H + maxf(6.0, (zone_h - MACHINE_H - 56.0) / 2.0), 2.0)
	_mx = snappedf((w - MACHINE_W) / 2.0, 2.0)
	carcasse.position = Vector2(_mx, _my)
	ombre_machine.position = Vector2(_mx + 12.0, _my + 18.0)
	ombre_machine.size = Vector2(MACHINE_W - 8.0, MACHINE_H - 6.0)
	bandeau.position = Vector2(-8.0, _bas - 14.0)
	bandeau.size = Vector2(w + 16.0, h - _bas + 30.0)
	lbl_enseigne.position = Vector2(_mx + 36.0, _my + 32.0)
	lbl_enseigne.size = Vector2(276, 20)
	for i in 3:
		reels[i].position = Vector2(_mx + float(14 + 20 * i) * 4.0 + 8.0, _my + 104.0)
	lbl_roue.position = Vector2(_mx + 92.0, _my + 212.0)
	lbl_roue.size = Vector2(168, 20)
	for i in ampoules.size():
		ampoules[i].position = Vector2(_mx, _my) + ampoules_off[i]
	lbl_msg.position = Vector2(0, _my + MACHINE_H + 10.0)
	lbl_msg.size = Vector2(w, 40)
	lbl_msg2.position = Vector2(0, _my + MACHINE_H + 52.0)
	lbl_msg2.size = Vector2(w, 24)
	# upgrades
	var bw: float = floorf((w - 32.0 - 16.0) / 3.0 / 2.0) * 2.0
	for i in 3:
		btn_upg[i].size = Vector2(bw, 96)
		btn_upg[i].position = Vector2(16.0 + float(i) * (bw + 8.0), y_upg)
	btn_carte.size = Vector2(w - 32.0, 56)
	btn_carte.position = Vector2(16, y_carte)
	# rangee du bas : jauge | infos | levier
	jauge.position = Vector2(12, _bas)
	levier.position = Vector2(w - LEVIER_W - 16.0, _bas)
	var mx0: float = 116.0
	var mw: float = w - 272.0
	lbl_mult.position = Vector2(mx0, _bas + 4.0)
	lbl_mult.size = Vector2(mw, 40)
	lbl_chauffe.position = Vector2(mx0, _bas + 52.0)
	lbl_chauffe.size = Vector2(mw, 20)
	lbl_etat.position = Vector2(mx0, _bas + 82.0)
	lbl_etat.size = Vector2(mw, 60)
	btn_mute.position = Vector2(mx0 + snappedf((mw - 100.0) / 2.0, 2.0), _bas + 168.0)
	flash.size = _vue

# ---------------------------------------------------------------------------
# Levier tactile : tap court / tap maintenu
# ---------------------------------------------------------------------------

func _on_levier_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_presse(st.position, st.index)
		else:
			_relache(st.index)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# un toucher genere aussi un clic « emule » : on l'ignore (le toucher est deja pris en compte)
		if mb.device == InputEvent.DEVICE_ID_EMULATION or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_presse(mb.position, -1)
		else:
			_relache(-1)

func _zone_de(pos: Vector2) -> int:
	var zones: int = Game.nb_jauges() if Game.machine == "ruche" else 2
	return clampi(int(pos.y / (LEVIER_H / float(zones))), 0, zones - 1)

func _presse(pos: Vector2, idx: int) -> void:
	if _appuye:
		return   # un seul doigt a la fois sur le levier
	_appuye = true
	_appui_idx = idx
	_appui_ms = Time.get_ticks_msec()
	_appui_pos = pos
	_appui_zone = _zone_de(pos)
	levier_spr.texture = Pixels.tex("levier_bas")

func _relache(idx: int) -> void:
	if not _appuye or idx != _appui_idx:
		return
	_appuye = false
	_appui_idx = -2
	levier_spr.texture = Pixels.tex("levier_haut")
	levier_spr.modulate = Color.WHITE
	var duree: int = Time.get_ticks_msec() - _appui_ms
	_dernier_tap_pos = levier.position + _appui_pos
	Game.tap(_appui_zone, duree >= Balance.TAP_COURT_MAX_MS)

# ---------------------------------------------------------------------------
# Boutons
# ---------------------------------------------------------------------------

func _acheter(i: int) -> void:
	if Game.acheter_upgrade(i):
		Sfx.jouer("tap")
		var haut_btn: Vector2 = btn_upg[i].position + Vector2(btn_upg[i].size.x / 2.0, -4.0)
		_flottant("NIV %d" % Game.niveaux[i], haut_btn, Pal.VERT, 16)
		if Game.mode_arcade():
			_salve(haut_btn + Vector2(0, 20), Pal.VERT, 18, 260.0)
			Sfx.jouer("table", 1.4)
		_maj_boutons()

func _fmt_decimal(x: float) -> String:
	var s: String = ("%.1f" % x).replace(".", ",")
	if s.ends_with(",0"):
		s = s.substr(0, s.length() - 2)
	return s

func _maj_boutons() -> void:
	for i in 3:
		var b: Button = btn_upg[i]
		var niv: int = Game.niveaux[i]
		var effet: String = ""
		match i:
			0:
				effet = "+%s/s" % Game.fmt_compact(Balance.EMPLOYE_JETONS_S * float(niv))
			1:
				effet = "GAIN %s" % _fmt_decimal(Game.base_gain())
			2:
				effet = "MAX %d" % int(Game.chauffe_max())
		var txt: String = "%s\nNIV %d  %s\n%s" % [Balance.UPG_NOMS[i], niv, effet, Game.fmt_compact(Game.prix_upgrade(i))]
		if b.text != txt:
			b.text = txt
		b.disabled = not Game.peut_acheter(i)
		var coul_prix: String = "vert" if Game.prix_upgrade(i) <= Game.jetons else "prune"
		if str(b.get_meta("schema", "")) != coul_prix:
			b.set_meta("schema", coul_prix)
			Pixels.habiller(b, coul_prix)
	# bouton de carte active (Coup de barre)
	var t: String = "CARTE ACTIVE : AUCUNE"
	var actif: bool = false
	if Game.has_carte("coup_barre"):
		if Game.gel_restant > 0.0:
			t = "CHAUFFE GELÉE ! %d s" % int(ceilf(Game.gel_restant))
		elif Game.coup_dispo:
			t = "COUP DE BARRE (1×/TABLE)"
			actif = Game.phase == Game.Phase.JEU
		else:
			t = "COUP DE BARRE : UTILISÉ"
	if btn_carte.text != t:
		btn_carte.text = t
	btn_carte.disabled = not actif

# ---------------------------------------------------------------------------
# Game feel
# ---------------------------------------------------------------------------

func _message(texte: String, couleur: Color, sous: String = "", duree: float = 1.6) -> void:
	lbl_msg.text = texte
	lbl_msg.add_theme_color_override("font_color", couleur)
	lbl_msg2.text = sous
	lbl_msg.modulate.a = 1.0
	lbl_msg2.modulate.a = 1.0
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.set_parallel(true)
	_msg_tween.tween_property(lbl_msg, "modulate:a", 0.0, 0.4).set_delay(duree)
	_msg_tween.tween_property(lbl_msg2, "modulate:a", 0.0, 0.4).set_delay(duree)

func _flottant(texte: String, centre: Vector2, couleur: Color, taille: int = 16) -> void:
	var ft: FloatText = FloatTextScene.instantiate()
	racine.add_child(ft)
	ft.lancer(texte, centre, couleur, taille)

## Salve de particules CPUParticles2D de 2x2 px.
func _salve(pos: Vector2, couleur: Color, nombre: int, vitesse: float, gravite: float = 500.0) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.amount = nombre
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = vitesse * 0.5
	p.initial_velocity_max = vitesse
	p.gravity = Vector2(0, gravite)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	p.color = couleur
	p.z_index = 15
	racine.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _flash(alpha: float, duree: float) -> void:
	flash.modulate.a = alpha
	var tw: Tween = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, duree)

func _reels_repos() -> void:
	var idle: Array[String] = ["cerise", "cloche", "sept"]
	for i in 3:
		reels[i].texture = Pixels.tex("sym_" + idle[i])
		reels[i].modulate = Color.WHITE if Game.a_une_roue() else Color(1, 1, 1, 0.3)

# ---------------------------------------------------------------------------
# Reactions aux signaux de Game
# ---------------------------------------------------------------------------

func _on_tap(gain: float, tenu: bool) -> void:
	var chaud: bool = Game.dernier_tap_chaud
	var ratio: float = clampf(Game.chauffe_courante() / maxf(1.0, Game.chauffe_max()), 0.0, 1.0)
	# arcade : le son monte en gamme quand ca chauffe ; classique : son fixe
	Sfx.jouer("tap", 0.85 + 0.9 * ratio if Game.mode_arcade() else 1.0)
	var coul: Color = Pal.ROUGE if chaud else (Pal.ORANGE if tenu else Pal.CREME)
	_flottant("+" + Game.fmt_compact(gain), _dernier_tap_pos + Vector2(0, -50), coul, 32 if (tenu or chaud) else 16)
	if chaud:
		_flottant("CHAUD !", _dernier_tap_pos + Vector2(0, -92), Pal.ORANGE, 16)
	_salve(_dernier_tap_pos, Pal.ROUGE if chaud else (Pal.DORE if tenu else Pal.ORANGE), 14 if (tenu or chaud) else 6, 260.0 if (tenu or chaud) else 180.0)

func _on_surchauffe(_g: int) -> void:
	Sfx.jouer("surchauffe")
	_shake = 8.0
	_flash(0.55, 0.6)
	_message("SURCHAUFFE !", Pal.ROUGE, "Machine verrouillée…", 1.2)
	_salve(Vector2(_mx + MACHINE_W / 2.0, _my + MACHINE_H / 2.0), Pal.ROUGE, 36, 420.0)
	_salve(levier.position + Vector2(LEVIER_W / 2.0, 80.0), Pal.ORANGE, 24, 320.0)

func _on_roue_lancee(res: Array) -> void:
	_spin_res = res
	_spin_t = 0.0
	_spin_chg = [0.0, 0.0, 0.0]
	Sfx.jouer("spin" if Game.mode_arcade() else "spin_lent")

func _on_roue_resultat(res: Array, _coef: float, gain: float, type: String) -> void:
	for i in 3:
		reels[i].texture = Pixels.tex("sym_" + str(res[i]))
	var centre: Vector2 = Vector2(_mx + MACHINE_W / 2.0, _my + MACHINE_H + 6.0)
	if type == "rate":
		_flottant("+" + Game.fmt_compact(gain), centre, Pal.CREME, 16)
		if res[0] == res[1] or res[1] == res[2] or res[0] == res[2]:
			_message("PRESQUE !", Pal.ORANGE, "un rouleau de plus...", 1.0)
		return
	_flottant("+" + Game.fmt_compact(gain), centre, Pal.DORE, 32)
	for r: TextureRect in reels:
		r.modulate = Color(2.0, 2.0, 2.0)
		var tw: Tween = create_tween()
		tw.tween_property(r, "modulate", Color.WHITE, 0.5)
	if type == "jackpot":
		Sfx.jouer("jackpot")
		_shake = 6.0
		if Game.mode_arcade():
			_ralenti()
		_message("JACKPOT !", Pal.DORE, "+" + Game.fmt_entier(gain), 2.0)
		_salve(Vector2(_mx + MACHINE_W / 2.0, _my + 130.0), Pal.DORE, 60, 460.0, 300.0)
		_salve(Vector2(_mx + MACHINE_W / 2.0, _my + 130.0), Pal.ORANGE, 40, 320.0, 300.0)
	elif type == "sept":
		Sfx.jouer("jackpot")
		_message("TRIPLE SEPT !", Pal.ROUGE, "", 1.4)
		_salve(Vector2(_mx + MACHINE_W / 2.0, _my + 130.0), Pal.ROUGE, 30, 360.0, 300.0)
	else:
		Sfx.jouer("table")
		_salve(Vector2(_mx + MACHINE_W / 2.0, _my + 130.0), Pal.VERT, 20, 300.0, 300.0)

## Ralenti dramatique (hit-stop) : le temps ralentit une fraction de seconde, puis revient.
func _ralenti() -> void:
	Engine.time_scale = Balance.RALENTI_FACTEUR
	get_tree().create_timer(Balance.RALENTI_DUREE, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# ---------------------------------------------------------------------------
# Piece d'or : bonus aleatoire a toucher (le « golden cookie » de la machine)
# ---------------------------------------------------------------------------

func _gerer_piece(delta: float) -> void:
	if _piece != null and not is_instance_valid(_piece):
		_piece = null
	if Game.phase != Game.Phase.JEU or not Game.mode_arcade():
		if _piece != null:
			_piece.queue_free()
			_piece = null
		return
	if _piece == null:
		_piece_attente -= delta
		if _piece_attente <= 0.0:
			_creer_piece()
		return
	_piece_t -= delta
	var t: float = Time.get_ticks_msec() / 1000.0
	_piece.position = _piece_base + Vector2(0.0, 8.0 * sin(t * 5.0))
	_piece.rotation = deg_to_rad(10.0 * sin(t * 3.0))
	# clignote pendant la derniere seconde, puis disparait
	if _piece_t < 1.0:
		_piece.modulate.a = 1.0 if fmod(_piece_t * 8.0, 1.0) > 0.5 else 0.25
	if _piece_t <= 0.0:
		_piece.queue_free()
		_piece = null
		_piece_attente = randf_range(Balance.PIECE_DELAI_MIN, Balance.PIECE_DELAI_MAX)

func _creer_piece() -> void:
	var p: Control = Control.new()
	p.size = Vector2(96, 96)                 # zone tactile genereuse
	p.pivot_offset = Vector2(48, 48)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.z_index = 10
	var img: TextureRect = Pixels.rect(Pixels.tex("sym_jackpot"))
	img.position = Vector2(16, 16)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(img)
	var x: float = randf_range(24.0, _vue.x - 120.0)
	var y: float = randf_range(HUD_H + 10.0, _my + MACHINE_H - 90.0)
	_piece_base = Vector2(snappedf(x, 2.0), snappedf(y, 2.0))
	p.position = _piece_base
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_ramasser_piece())
	racine.add_child(p)
	_piece = p
	_piece_t = Balance.PIECE_DUREE
	p.scale = Vector2(0.2, 0.2)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.jouer("tap", 1.8)

func _ramasser_piece() -> void:
	if _piece == null or not is_instance_valid(_piece):
		return
	var centre: Vector2 = _piece.position + Vector2(48, 48)
	_piece.queue_free()
	_piece = null
	_piece_attente = randf_range(Balance.PIECE_DELAI_MIN, Balance.PIECE_DELAI_MAX)
	var gain: float = Game.piece_bonus()
	if gain <= 0.0:
		return
	Sfx.jouer("jackpot", 1.2)
	_flottant("PIÈCE ! +" + Game.fmt_compact(gain), centre, Pal.DORE, 32)
	_salve(centre, Pal.DORE, 36, 380.0, 300.0)
	_salve(centre, Pal.CREME, 16, 260.0, 300.0)
	_shake = 3.0

func _on_table_demarree(i: int) -> void:
	if _piece != null and is_instance_valid(_piece):
		_piece.queue_free()
	_piece = null
	_piece_attente = randf_range(Balance.PIECE_DELAI_MIN, Balance.PIECE_DELAI_MAX)
	fond.regler(ACCENTS[i % ACCENTS.size()], 0.35, 1.0)
	_reels_repos()
	_spin_t = -1.0
	if Tables.est_boss(i):
		var nom_boss: String = str(Tables.obtenir(i)["boss"])
		_message("BOSS !", Pal.ROUGE, "%s : %s" % [nom_boss, Tables.texte_contrainte(i).get_slice(": ", 1)], 2.6)
		_flash(0.35, 0.6)
		_shake = 5.0
		Sfx.jouer("surchauffe", 0.7)
	else:
		_message("TABLE %d" % (i + 1), Pal.CREME, Tables.texte_contrainte(i), 1.6)
	_maj_boutons()
	if i == 0 and not Save.tuto_fait and not Game.defi and _tuto_etape < 0:
		_tuto_aller(0)

func _on_table_reussie(i: int) -> void:
	Sfx.jouer("table")
	_message("TABLE RÉUSSIE !", Pal.VERT, "", 2.0)
	_salve(Vector2(_mx + MACHINE_W / 2.0, _my + 100.0), Pal.VERT, 50, 420.0, 300.0)
	if i >= Tables.nombre() - 1:
		return   # derniere table : run_terminee prend le relais
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree() or Game.phase != Game.Phase.CARTES:
		return
	if Game.preparer_offre():
		add_child(CardPickScene.instantiate())
	else:
		Game.table_suivante()

func _on_table_ratee(_i: int, raison: String) -> void:
	Sfx.jouer("surchauffe")
	_shake = 6.0
	_flash(0.4, 0.8)
	if Game.dernier_pardon:
		_message("TABLE RATÉE !", Pal.ORANGE, raison + "  Le Phénix t'épargne !", 1.6)
	else:
		_message("TABLE RATÉE !", Pal.ROUGE, raison + "  -1 cœur", 1.6)

func _on_bouclier() -> void:
	Sfx.jouer("table", 0.8)
	_message("BOUCLIER !", Pal.VERT, "Surchauffe annulée", 1.2)
	_salve(levier.position + Vector2(LEVIER_W / 2.0, 80.0), Pal.VERT, 24, 300.0)

# ---------------------------------------------------------------------------
# Tutoriel de la 1re partie : 3 bulles (tape, chauffe, zone chaude), table 1 uniquement
# ---------------------------------------------------------------------------

const TUTO: Array = [
	["1. TAPE !", "Tape sur le levier pour gagner des jetons. Appui long = ×3."],
	["2. LA CHAUFFE", "Plus tu tapes vite, plus ça chauffe : le multiplicateur monte. À 100 %, SURCHAUFFE !"],
	["3. ZONE CHAUDE", "Au-delà de 80 %, chaque tap vaut ×1,5. Joue avec le feu, mais ne craque pas."],
]

func _tuto_aller(etape: int) -> void:
	if _bulle != null and is_instance_valid(_bulle):
		_bulle.queue_free()
		_bulle = null
	_tuto_etape = etape
	_tuto_t = 0.0
	if etape >= TUTO.size():
		_tuto_etape = 99
		Save.tuto_fait = true
		Save.ecrire()
		return
	var w: float = _vue.x
	var bh: float = 104.0
	var by: float = _bas - 8.0 - 56.0 - 8.0 - 96.0 - 4.0
	_bulle = Pixels.panneau(w - 32.0, bh, "panel_or")
	_bulle.position = Vector2(16, by)
	_bulle.z_index = 25
	_bulle.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: Label = Pixels.label(str(TUTO[etape][0]), 16, Pal.DORE)
	t.position = Vector2(16, 10)
	_bulle.add_child(t)
	var d: Label = Pixels.label(str(TUTO[etape][1]), 16, Pal.CREME)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(16, 36)
	d.size = Vector2(w - 32.0 - 32.0, 64)
	_bulle.add_child(d)
	var pas: Label = Pixels.label("%d/3" % (etape + 1), 8, Pal.GRIS)
	pas.position = Vector2(w - 32.0 - 40.0, 14)
	_bulle.add_child(pas)
	# fleche vers le levier (etape 1) ou vers la jauge (etapes 2 et 3)
	var fl: Control = Control.new()
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx: float = (w - LEVIER_W / 2.0 - 16.0 - 16.0) if etape == 0 else (60.0 - 16.0)
	fl.position = Vector2(cx, bh - 2.0)
	fl.draw.connect(func() -> void:
		for r in 5:
			fl.draw_rect(Rect2(-float(8 - 2 * r), float(r) * 4.0, float(16 - 4 * r + 2), 4.0), Pal.DORE))
	_bulle.add_child(fl)
	add_child(_bulle)
	_bulle.pivot_offset = Vector2((w - 32.0) / 2.0, bh)
	_bulle.scale = Vector2(0.7, 0.7)
	_bulle.modulate.a = 0.0
	var tw: Tween = _bulle.create_tween().set_parallel(true)
	tw.tween_property(_bulle, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bulle, "modulate:a", 1.0, 0.15)
	_bulle.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_tuto_aller(_tuto_etape + 1))
	Sfx.jouer("table", 1.3)

## Fait avancer le tutoriel selon ce que fait le joueur (appele a chaque frame).
func _tuto_tick(delta: float) -> void:
	if _tuto_etape < 0 or _tuto_etape >= 99:
		return
	_tuto_t += delta
	var ratio: float = Game.chauffe_courante() / maxf(1.0, Game.chauffe_max())
	var seuil: float = Balance.ZONE_CHAUDE_SEUIL if Game.mode_arcade() else 0.7
	match _tuto_etape:
		0:
			if Game.taps >= 5 or _tuto_t > 12.0:
				_tuto_aller(1)
		1:
			if ratio >= 0.5 and _tuto_t > 2.5 or _tuto_t > 9.0:
				_tuto_aller(2)
		2:
			if _tuto_t > 7.0 or (ratio >= seuil and _tuto_t > 4.0):
				_tuto_aller(3)
	if Game.phase != Game.Phase.JEU and _bulle != null and is_instance_valid(_bulle):
		_bulle.visible = false
	elif _bulle != null and is_instance_valid(_bulle):
		_bulle.visible = true

func _on_run_terminee(_resume: Dictionary) -> void:
	await get_tree().create_timer(1.8).timeout
	if is_inside_tree():
		Fx.aller("res://scenes/GameOver.tscn")

# ---------------------------------------------------------------------------
# Boucle d'affichage
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_gerer_piece(delta)
	_tuto_tick(delta)
	# neons animes
	_ampoule_t += delta
	if _ampoule_t >= 0.3:
		_ampoule_t = 0.0
		_ampoule_phase = 1 - _ampoule_phase
		for i in ampoules.size():
			ampoules[i].texture = Pixels.tex("ampoule_on" if (i + _ampoule_phase) % 2 == 0 else "ampoule_off")
	# tremblement (decroit, toujours sur la grille de 2 px)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - 24.0 * delta)
		var m: int = int(_shake)
		racine.position = Vector2(float(randi_range(-m, m)) * 2.0, float(randi_range(-m, m)) * 2.0)
	elif racine.position != Vector2.ZERO:
		racine.position = Vector2.ZERO
	# rouleaux qui tournent (arret echelonne : 50 / 75 / 100 % de ROUE_DUREE)
	if _spin_t >= 0.0:
		_spin_t += delta
		var duree_roue: float = Game.roue_duree()
		var arrets: Array[float] = [duree_roue * 0.5, duree_roue * 0.75, duree_roue]
		var actifs: Array[String] = Game.symboles_actifs()
		for i in 3:
			if _spin_t >= arrets[i]:
				reels[i].texture = Pixels.tex("sym_" + str(_spin_res[i]))
			else:
				_spin_chg[i] -= delta
				if _spin_chg[i] <= 0.0:
					_spin_chg[i] = 0.04 if Game.mode_arcade() else 0.06
					reels[i].texture = Pixels.tex("sym_" + actifs.pick_random())
		if _spin_t >= duree_roue + 0.05:
			_spin_t = -1.0
	# levier maintenu : retour visuel quand le seuil de tap maintenu est franchi
	if _appuye:
		var tenu: bool = Time.get_ticks_msec() - _appui_ms >= Balance.TAP_COURT_MAX_MS
		levier_spr.modulate = Color(1.5, 1.2, 0.8) if tenu else Color.WHITE
	# jauge + textes
	jauge.valeurs = Game.chauffes
	jauge.verrous = Game.verrous
	jauge.maximum = Game.chauffe_max()
	var mult: float = Game.multiplicateur()
	lbl_mult.text = "×" + ("%.2f" % mult).replace(".", ",")
	lbl_mult.add_theme_color_override("font_color", Pal.VERT if mult < 2.0 else (Pal.ORANGE if mult < 3.2 else Pal.ROUGE))
	if Game.machine == "ruche":
		lbl_chauffe.text = "3 JAUGES"
	else:
		lbl_chauffe.text = "CHAUFFE %d/%d" % [int(Game.chauffe_courante()), int(Game.chauffe_max())]
	if not Game.a_une_roue():
		lbl_roue.text = "SANS ROUE"
	elif Game.roue_en_cours:
		lbl_roue.text = "ROUE…"
	else:
		lbl_roue.text = "ROUE %d/%d" % [Game.taps_roue, Game.taps_par_roue()]
	var verrou_max: float = 0.0
	for v: float in Game.verrous:
		verrou_max = maxf(verrou_max, v)
	if verrou_max > 0.0:
		lbl_etat.text = "SURCHAUFFE\n%s s" % _fmt_decimal(verrou_max)
		lbl_etat.add_theme_color_override("font_color", Pal.ROUGE)
	elif Game.gel_restant > 0.0:
		lbl_etat.text = "GEL\n%d s" % int(ceilf(Game.gel_restant))
		lbl_etat.add_theme_color_override("font_color", Pal.CREME)
	elif Game.faibles > 0:
		lbl_etat.text = "TAPS ×0,5\n(%d)" % Game.faibles
		lbl_etat.add_theme_color_override("font_color", Pal.ORANGE)
	else:
		lbl_etat.text = ""
	# le fond tourne de plus en plus vite quand la machine chauffe
	fond.regler_vitesse(1.0 + 2.5 * clampf(Game.chauffe_courante() / maxf(1.0, Game.chauffe_max()), 0.0, 1.0))
	# les boutons achetables « respirent »
	for b: Button in btn_upg:
		if not b.disabled:
			var k: float = 1.0 + 0.012 * sin(float(Time.get_ticks_msec()) / 1000.0 * 6.0)
			b.pivot_offset = b.size / 2.0
			b.scale = Vector2(k, k)
		elif b.scale != Vector2.ONE:
			b.scale = Vector2.ONE
	# boutons : disponibilite selon les jetons (10 fois/s suffit)
	_ui_acc += delta
	if _ui_acc >= 0.1:
		_ui_acc = 0.0
		_maj_boutons()
