extends Node
## Etat de la run + toute la logique de jeu. Les scenes ECOUTENT les signaux,
## elles ne se parlent pas entre elles. Constantes d'equilibrage : data/Balance.gd.

const Balance = preload("res://data/Balance.gd")
const Cards = preload("res://data/Cards.gd")
const Tables = preload("res://data/Tables.gd")
const Machines = preload("res://data/Machines.gd")

enum Phase { ATTENTE, JEU, TRANSITION, CARTES, FINI }

# --- Signaux ---------------------------------------------------------------
signal jetons_changed(jetons: float)
signal chauffe_changed(chauffes: Array, chauffe_max: float)
signal surchauffe(jauge: int)
signal roue_lancee(rouleaux: Array)                       # resultat deja tire, paiement dans roue_duree()
signal roue_resultat(rouleaux: Array, coef: float, gain: float, type: String)
signal tap_effectue(gain: float, tenu: bool)
signal jackpot(gain: float)
signal table_demarree(index: int)
signal table_reussie(index: int)
signal table_ratee(index: int, raison: String)
signal run_terminee(resume: Dictionary)
signal vies_changed(vies: int)
signal upgrades_changed()
signal contrainte_changed()
signal cartes_changed()
signal coup_de_barre_changed()
signal bouclier_utilise()
signal pardon_phenix()

# --- Etat de la run --------------------------------------------------------
var phase: int = Phase.FINI
var machine: String = ""
var jetons: float = 0.0
var pic_jetons: float = 0.0
var meilleur_jackpot: float = 0.0
var vies: int = Balance.VIES_DEPART
var table_index: int = 0
var temps_restant: float = 0.0
var cartes: Array[String] = []
var symboles_retires: Array[String] = []
var niveaux: Array[int] = [0, 0, 0]       # employe, levier poli, radiateur
var taps: int = 0                         # compteur de taps de la run
var taps_roue: int = 0                    # taps depuis la derniere roue
var chauffes: Array[float] = [0.0]        # une jauge (3 avec la Ruche)
var depuis_tap: Array[float] = [0.0]
var verrous: Array[float] = [0.0]         # secondes de verrouillage restantes par jauge
var faibles: int = 0                      # taps restants a x0,5 apres surchauffe
var gel_restant: float = 0.0              # Coup de barre
var coup_dispo: bool = false
var derniere_zone: int = -1
var dernier_tap_chaud: bool = false      # le dernier tap etait en zone chaude (x1,5)
var surchauffes_table: int = 0
var surchauffes_run: int = 0
var jackpots_table: int = 0
var contrainte_ok: bool = false
var gain_fenetre: float = 0.0             # gains sur la fenetre glissante (table 3)
var aimants: int = 0                      # crochet pour les machines a venir (poids jackpot)
var offre: Array[String] = []
var dernier_resume: Dictionary = {}
var roue_en_cours: bool = false
var relance_active: bool = false          # bonus « rejoue vite » : plombs x1,5 a la fin de la prochaine run
var serie_proposee: bool = false          # bonus quotidien deja propose depuis le lancement ?
var mise_active: int = 0                  # mise de la run (0 = MISE 1) ; toujours 0 en defi du jour
var defi: bool = false                    # run = defi du jour (graine fixe, machine de base, modificateur)
var defi_modif: String = ""
var jackpots_run: int = 0
var taps_chauds: int = 0                  # taps en zone chaude sur la run
var pieces_run: int = 0
var bosses_run: int = 0
var bouclier_dispo: bool = false
var dernier_pardon: bool = false          # la derniere table ratee a ete pardonnee par le Phenix
var dernier_gain_surchauffe: float = 0.0  # gain du Reacteur a la derniere surchauffe

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _phenix_utilise: bool = false
var _interets_acc: float = 0.0

var _roue_t: float = 0.0
var _roue_res: Array = []
var _roue_valeur: float = 0.0
var _distrib_fait: bool = false
var _pause: float = 0.0
var _stagiaire_acc: float = 0.0
var _jetons_dirty: bool = false
var _horloge: float = 0.0
var _ev_t: PackedFloat64Array = PackedFloat64Array()
var _ev_v: PackedFloat64Array = PackedFloat64Array()

# ---------------------------------------------------------------------------
# Formatage (nombres francais)
# ---------------------------------------------------------------------------

## 1234567 -> « 1 234 567 »
func fmt_entier(x: float) -> String:
	var n: int = int(floorf(x + 0.0001))
	var s: String = str(absi(n))
	var out: String = ""
	var compte: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		compte += 1
		if compte % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out

## 1200 -> « 1,2 k » ; 5400000 -> « 5,4 M » (virgule francaise).
func fmt_compact(x: float) -> String:
	var v: float = absf(x)
	var sign: String = "-" if x < 0.0 else ""
	if v < 1000.0:
		return sign + str(int(floorf(v)))
	var suffixes: Array[String] = [" k", " M", " Md", " Bn", " Bd"]
	var div: float = 1000.0
	var idx: int = 0
	while idx < suffixes.size() - 1 and v >= div * 1000.0:
		div *= 1000.0
		idx += 1
	var q: float = v / div
	if q >= 1000.0:   # au-dela des suffixes : notation scientifique
		return sign + ("%.1e" % v).replace(".", ",")
	var s: String = ("%.0f" % q) if q >= 100.0 else ("%.1f" % q)
	s = s.replace(".", ",")
	if s.ends_with(",0"):
		s = s.substr(0, s.length() - 2)
	return sign + s + suffixes[idx]

## Duree courte : 78,4 -> « 78 s »
func fmt_secondes(x: float) -> String:
	return "%d s" % int(ceilf(maxf(0.0, x)))

# ---------------------------------------------------------------------------
# Lecture de l'etat
# ---------------------------------------------------------------------------

func has_carte(id: String) -> bool:
	return cartes.has(id)

func nb_jauges() -> int:
	return chauffes.size()

func table_type() -> String:
	return str(Tables.obtenir(table_index)["type"])

func chauffe_max() -> float:
	var m: float = Balance.CHAUFFE_MAX_BASE + Balance.RADIATEUR_CHAUFFE * float(niveaux[2])
	if machine == "glacon":
		m += Balance.GLACON_CHAUFFE_MAX
	if defi and defi_modif == "fournaise":
		m -= 5.0
	if table_type() == "chaud":
		m *= Balance.BOSS_CHAUD_MAX
	return maxf(6.0, roundf(m))

func refroidissement() -> float:
	if machine == "vapeur":
		return 0.0
	var r: float = Balance.REFROID_VITESSE + Balance.RADIATEUR_REFROID * float(niveaux[2])
	if has_carte("ventilo"):
		r += Balance.VENTILO_REFROID
	if machine == "glacon":
		r *= Balance.GLACON_REFROID
	if defi and defi_modif == "froid":
		r *= 2.0
	if mise_active >= 4:
		r *= Balance.MISE_REFROID
	return r

func duree_verrou() -> float:
	var d: float = Balance.VERROU_SURCHAUFFE
	if machine == "becane":
		d = Balance.VERROU_BECANE
	elif machine == "vapeur":
		d = Balance.VERROU_VAPEUR
	if mise_active >= 3:
		d += Balance.MISE_VERROU
	return d

func mult_par_chauffe() -> float:
	return Balance.MULT_PAR_CHAUFFE * (1.5 if defi and defi_modif == "fournaise" else 1.0)

func base_gain() -> float:
	return Balance.BASE_GAIN_DEPART * pow(Balance.LEVIER_FACTEUR, float(niveaux[1]))

func chauffe_courante() -> float:
	var m: float = 0.0
	for c: float in chauffes:
		m = maxf(m, c)
	return m

func multiplicateur_jauge(g: int) -> float:
	var m: float = 1.0 + mult_par_chauffe() * chauffes[g]
	if machine == "becane":
		m *= Balance.BECANE_MULT
	return m

## Multiplicateur affiche / utilise pour les conditions : celui de la jauge la plus chaude.
func multiplicateur() -> float:
	var m: float = 1.0 + mult_par_chauffe() * chauffe_courante()
	if machine == "becane":
		m *= Balance.BECANE_MULT
	return m

func valeur_tap() -> float:
	return base_gain() * multiplicateur()

func jauge_de_zone(zone: int) -> int:
	if machine == "ruche":
		return clampi(zone, 0, chauffes.size() - 1)
	return 0

func est_verrouille(g: int) -> bool:
	return verrous[g] > 0.0

func objectif() -> float:
	var o: float = float(Tables.obtenir(table_index)["objectif"])
	if mise_active >= 1:
		o *= Balance.MISE_OBJECTIF
	if has_carte("usurier"):
		o *= Balance.USURIER_OBJECTIF
	return roundf(o)

func a_une_roue() -> bool:
	return machine != "muet" and table_type() != "sans_roue"

func taps_par_roue() -> int:
	return Balance.TURBO_TAPS_PAR_ROUE if has_carte("turbo") else Balance.TAPS_PAR_ROUE

# ---------------------------------------------------------------------------
# Cycle de la run
# ---------------------------------------------------------------------------

## Prepare une nouvelle run (n'emet rien ; Run.gd appelle ensuite commencer()).
## Mode ARCADE (rapide + bonus fun) ou CLASSIQUE (version d'origine). Choisi dans le menu.
func mode_arcade() -> bool:
	return Save.mode != "classique"

func roue_duree() -> float:
	return Balance.ROUE_DUREE_ARCADE if mode_arcade() else Balance.ROUE_DUREE_CLASSIQUE

func nouvelle_run(defi_du_jour: bool = false) -> void:
	defi = defi_du_jour
	defi_modif = str(Save.defi_modificateur()["id"]) if defi else ""
	mise_active = 0 if defi else Save.mise
	machine = "" if defi else Save.machine_active
	if defi:
		_rng.seed = Save.defi_graine()
	else:
		_rng.randomize()
	jackpots_run = 0
	taps_chauds = 0
	pieces_run = 0
	bosses_run = 0
	_phenix_utilise = false
	dernier_pardon = false
	_interets_acc = 0.0
	var nb: int = Balance.RUCHE_JAUGES if machine == "ruche" else 1
	chauffes.resize(nb)
	depuis_tap.resize(nb)
	verrous.resize(nb)
	chauffes.fill(0.0)
	depuis_tap.fill(0.0)
	verrous.fill(0.0)
	jetons = 0.0
	pic_jetons = 0.0
	meilleur_jackpot = 0.0
	vies = Balance.VIES_DEPART - (1 if mise_active >= 2 else 0)
	table_index = 0
	cartes = []
	symboles_retires = []
	niveaux = [0, 0, 0]
	taps = 0
	surchauffes_run = 0
	aimants = Balance.AIMANT_MACHINE if machine == "aimant" else 0
	offre = []
	dernier_resume = {}
	_stagiaire_acc = 0.0
	_horloge = 0.0
	phase = Phase.ATTENTE

## Appele par Run.gd une fois ses signaux connectes.
func commencer() -> void:
	if phase == Phase.ATTENTE:
		_demarrer_table()
	else:
		_emettre_tout()

func _emettre_tout() -> void:
	jetons_changed.emit(jetons)
	chauffe_changed.emit(chauffes, chauffe_max())
	vies_changed.emit(vies)
	upgrades_changed.emit()
	contrainte_changed.emit()
	cartes_changed.emit()
	coup_de_barre_changed.emit()

func _demarrer_table() -> void:
	var t: Dictionary = Tables.obtenir(table_index)
	temps_restant = float(t["duree"])
	if mise_active >= 5:
		temps_restant *= Balance.MISE_DUREE
	if defi and defi_modif == "blitz":
		temps_restant = minf(temps_restant, 60.0)
	if has_carte("chrono"):
		temps_restant += Balance.CHRONO_BONUS_S
	temps_restant = roundf(temps_restant)
	chauffes.fill(0.0)
	depuis_tap.fill(0.0)
	verrous.fill(0.0)
	faibles = 0
	gel_restant = Balance.GIVRE_DUREE if has_carte("givre") else 0.0
	bouclier_dispo = has_carte("bouclier")
	coup_dispo = has_carte("coup_barre")
	derniere_zone = -1
	surchauffes_table = 0
	jackpots_table = 0
	contrainte_ok = false
	gain_fenetre = 0.0
	taps_roue = 0
	roue_en_cours = false
	_distrib_fait = false
	_ev_t.clear()
	_ev_v.clear()
	phase = Phase.JEU
	table_demarree.emit(table_index)
	_emettre_tout()

## Appele apres le choix de carte.
func table_suivante() -> void:
	if phase != Phase.CARTES:
		return
	table_index += 1
	_demarrer_table()

# ---------------------------------------------------------------------------
# Boucle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.TRANSITION:
		_pause -= delta
		if _pause <= 0.0:
			_demarrer_table()
		return
	if phase != Phase.JEU:
		return
	_horloge += delta
	temps_restant -= delta
	_tick_verrous(delta)
	_tick_chauffe(delta)
	_tick_auto(delta)
	_tick_roue(delta)
	_tick_fenetre()
	if _jetons_dirty:
		_jetons_dirty = false
		jetons_changed.emit(jetons)
	_verifier_objectif()
	if phase == Phase.JEU and temps_restant <= 0.0:
		_fin_du_temps()

func _tick_verrous(delta: float) -> void:
	var fini: bool = false
	for g in verrous.size():
		if verrous[g] > 0.0:
			verrous[g] = maxf(0.0, verrous[g] - delta)
			if verrous[g] == 0.0:
				fini = true
	if gel_restant > 0.0:
		gel_restant = maxf(0.0, gel_restant - delta)
		if gel_restant == 0.0:
			coup_de_barre_changed.emit()
	if fini:
		chauffe_changed.emit(chauffes, chauffe_max())

func _tick_chauffe(delta: float) -> void:
	var change: bool = false
	for g in chauffes.size():
		depuis_tap[g] += delta
		if gel_restant > 0.0 or verrous[g] > 0.0:
			continue
		if depuis_tap[g] >= Balance.REFROID_DELAI and chauffes[g] > 0.0:
			chauffes[g] = maxf(0.0, chauffes[g] - refroidissement() * delta)
			change = true
	if change:
		chauffe_changed.emit(chauffes, chauffe_max())

## Employes (upgrade) + stagiaire (carte) : revenus automatiques, sans chauffe.
func _tick_auto(delta: float) -> void:
	if niveaux[0] > 0:
		var f: float = Balance.EQUIPE_FACTEUR if has_carte("equipe") else 1.0
		_ajouter_jetons(Balance.EMPLOYE_JETONS_S * float(niveaux[0]) * f * delta)
	if machine == "banquier":
		_interets_acc += delta
		if _interets_acc >= Balance.BANQUIER_PERIODE:
			_interets_acc -= Balance.BANQUIER_PERIODE
			_ajouter_jetons(jetons * Balance.BANQUIER_TAUX)
	if has_carte("stagiaire"):
		_stagiaire_acc += delta * Balance.STAGIAIRE_TAPS_S
		while _stagiaire_acc >= 1.0:
			_stagiaire_acc -= 1.0
			_ajouter_jetons(valeur_tap())

func _tick_roue(delta: float) -> void:
	if not roue_en_cours:
		return
	_roue_t -= delta
	if _roue_t <= 0.0:
		_payer_roue()

## Fenetre glissante (table 3) : somme des gains des N dernieres secondes.
func _tick_fenetre() -> void:
	var t: Dictionary = Tables.obtenir(table_index)
	if t["type"] != "fenetre":
		return
	var duree: float = float(t["fenetre"])
	while _ev_t.size() > 0 and _horloge - _ev_t[0] > duree:
		_ev_t.remove_at(0)
		_ev_v.remove_at(0)
	var somme: float = 0.0
	for v: float in _ev_v:
		somme += v
	gain_fenetre = somme
	if not contrainte_ok and somme >= float(t["montant"]):
		contrainte_ok = true
		contrainte_changed.emit()

func _ajouter_jetons(montant: float) -> void:
	if montant <= 0.0:
		return
	if has_carte("usurier"):
		montant *= Balance.USURIER_GAINS
	jetons += montant
	pic_jetons = maxf(pic_jetons, jetons)
	_ev_t.append(_horloge)
	_ev_v.append(montant)
	_jetons_dirty = true

# ---------------------------------------------------------------------------
# Tap
# ---------------------------------------------------------------------------

## zone : zone du levier touchee (0/1, ou 0..2 avec la Ruche) ; tenu : appui >= 250 ms.
func tap(zone: int, tenu: bool) -> void:
	if phase != Phase.JEU:
		return
	var g: int = jauge_de_zone(zone)
	if verrous[g] > 0.0:
		return
	var gain: float = base_gain() * multiplicateur_jauge(g)
	# Zone chaude : jouer avec le feu = x1,5 (risque de surchauffe a 100 %)
	dernier_tap_chaud = mode_arcade() and gel_restant <= 0.0 and chauffes[g] >= chauffe_max() * Balance.ZONE_CHAUDE_SEUIL
	if dernier_tap_chaud:
		gain *= Balance.ZONE_CHAUDE_BONUS
	if dernier_tap_chaud:
		taps_chauds += 1
	if tenu:
		gain *= Balance.PARI_GAIN_TENU if has_carte("pari") else Balance.GAIN_TENU
	if machine == "muet":
		gain *= Balance.MUET_FACTEUR
	if machine == "jumeaux" and randf() < Balance.JUMEAUX_PROBA:
		gain *= 2.0
	if has_carte("combo") and (taps + 1) % Balance.COMBO_PERIODE == 0:
		gain *= Balance.COMBO_FACTEUR
	if has_carte("rythme"):
		gain *= Balance.RYTHME_BON if zone != derniere_zone else Balance.RYTHME_MAUVAIS
	if faibles > 0:
		gain *= Balance.FACTEUR_FAIBLE
		faibles -= 1
	derniere_zone = zone
	_ajouter_jetons(gain)
	taps += 1
	depuis_tap[g] = 0.0
	if gel_restant <= 0.0:
		var dh: float = Balance.CHAUFFE_TENU if tenu else Balance.CHAUFFE_COURT
		if has_carte("double_zero"):
			dh += Balance.DOUBLE_ZERO_CHAUFFE
		if has_carte("pari") and tenu:
			dh += Balance.PARI_CHAUFFE
		chauffes[g] += dh
	jetons_changed.emit(jetons)
	_jetons_dirty = false
	tap_effectue.emit(gain, tenu)
	if chauffes[g] >= chauffe_max():
		_surchauffer(g)
	else:
		chauffe_changed.emit(chauffes, chauffe_max())
	if phase != Phase.JEU:
		return
	if a_une_roue():
		taps_roue += 1
		if taps_roue >= taps_par_roue() and not roue_en_cours:
			taps_roue = 0
			_lancer_roue()
	_verifier_objectif()

func _surchauffer(g: int) -> void:
	if bouclier_dispo:
		bouclier_dispo = false
		chauffes[g] = chauffe_max() * 0.6
		chauffe_changed.emit(chauffes, chauffe_max())
		bouclier_utilise.emit()
		return
	dernier_gain_surchauffe = 0.0
	if machine == "reacteur":
		dernier_gain_surchauffe = base_gain() * multiplicateur_jauge(g) * Balance.REACTEUR_TAPS
		_ajouter_jetons(dernier_gain_surchauffe)
		jetons_changed.emit(jetons)
	chauffes[g] = 0.0
	verrous[g] = duree_verrou()
	faibles = Balance.TAPS_FAIBLES
	surchauffes_table += 1
	surchauffes_run += 1
	if has_carte("maison"):
		jetons -= jetons * Balance.MAISON_SURCHAUFFE_PERTE
		jetons_changed.emit(jetons)
	surchauffe.emit(g)
	chauffe_changed.emit(chauffes, chauffe_max())
	var t: Dictionary = Tables.obtenir(table_index)
	if t["type"] == "surchauffes" and surchauffes_table > int(t["max"]):
		_rater("Trop de surchauffes !")

# ---------------------------------------------------------------------------
# La roue
# ---------------------------------------------------------------------------

func symboles_actifs() -> Array[String]:
	var res: Array[String] = []
	for s: String in Balance.SYMBOLES:
		if symboles_retires.has(s):
			continue
		if s == "zero" and not has_carte("double_zero"):
			continue
		res.append(s)
	return res

## Poids d'un symbole sur un rouleau (formules du cahier des charges).
func poids(sym: String) -> float:
	var c: float = chauffe_courante()
	match sym:
		"cerise":
			return Balance.POIDS_CERISE
		"citron":
			return Balance.POIDS_CITRON
		"cloche":
			return Balance.POIDS_CLOCHE
		"sept":
			var ps: float = Balance.POIDS_SEPT + Balance.POIDS_SEPT_CHAUFFE * c
			if has_carte("fer_cheval"):
				ps += Balance.FER_CHEVAL_POIDS
			return ps
		"jackpot":
			var p: float = Balance.POIDS_JACKPOT + Balance.POIDS_JACKPOT_CHAUFFE * c \
				+ Balance.POIDS_JACKPOT_AIMANT * float(aimants)
			if has_carte("double_zero"):
				p += Balance.DOUBLE_ZERO_JACKPOT
			if has_carte("fer_cheval"):
				p += Balance.FER_CHEVAL_POIDS
			if defi and defi_modif == "chance":
				p *= 2.0
			return maxf(0.0, p)
		"zero":
			return Balance.POIDS_ZERO
	return 0.0

func _tirer_symbole(actifs: Array[String]) -> String:
	var total: float = 0.0
	for s: String in actifs:
		total += poids(s)
	if total <= 0.0:
		return actifs[0]
	var r: float = _rng.randf() * total
	for s: String in actifs:
		r -= poids(s)
		if r <= 0.0:
			return s
	return actifs[actifs.size() - 1]

func _tirer_rouleaux() -> Array:
	var actifs: Array[String] = symboles_actifs()
	# Distributeur : la premiere roue de chaque table donne un triple jackpot.
	if machine == "distributeur" and not _distrib_fait and actifs.has("jackpot"):
		_distrib_fait = true
		return ["jackpot", "jackpot", "jackpot"]
	var res: Array = []
	for i in 3:
		# Bandit manchot : le rouleau 1 est toujours un sept.
		if machine == "bandit" and i == 0 and actifs.has("sept"):
			res.append("sept")
		else:
			res.append(_tirer_symbole(actifs))
	_presque(res, actifs)
	return res

## « Presque ! » (dark pattern assume) : un tirage sans aucune paire devient parfois une paire
## visuelle, de preference sur sept/jackpot, pour faire croire qu'on etait a un rouleau du gros lot.
## Jamais de triple ajoute : le paiement (x0,3) est strictement identique.
func _presque(res: Array, actifs: Array[String]) -> void:
	if res[0] == res[1] or res[1] == res[2] or res[0] == res[2]:
		return
	if _rng.randf() >= Balance.PRESQUE_PROBA:
		return
	var hauts: Array[String] = []
	for s: String in ["jackpot", "sept"]:
		if actifs.has(s) and s != res[2]:
			hauts.append(s)
	if machine != "bandit" and not hauts.is_empty():
		res[0] = hauts[0]
		res[1] = hauts[0]
	else:
		res[1] = res[0]

func _lancer_roue() -> void:
	_roue_valeur = valeur_tap()           # valeur_tap figee au declenchement
	_roue_res = _tirer_rouleaux()
	roue_en_cours = true
	_roue_t = roue_duree()
	roue_lancee.emit(_roue_res)

func _payer_roue() -> void:
	roue_en_cours = false
	var res: Array = _roue_res
	var triple: bool = res[0] == res[1] and res[1] == res[2]
	var coef: float = Balance.TREFLE_COEF_RATE if has_carte("trefle") else Balance.COEF_RATE
	var type: String = "rate"
	if triple:
		type = res[0]
		coef = float(Balance.COEFS[type])
	var gain: float = coef * _roue_valeur * Balance.PAIEMENT_BASE_TAPS
	if has_carte("maison"):
		gain *= Balance.MAISON_PAIEMENT
	_ajouter_jetons(gain)
	if type == "jackpot":
		jackpots_table += 1
		jackpots_run += 1
		meilleur_jackpot = maxf(meilleur_jackpot, gain)
		jackpot.emit(gain)
	jetons_changed.emit(jetons)
	_jetons_dirty = false
	roue_resultat.emit(res, coef, gain, type)

## Piece d'or ramassee : renvoie les jetons gagnes (0 hors partie).
func piece_bonus() -> float:
	if phase != Phase.JEU or not mode_arcade():
		return 0.0
	var gain: float = valeur_tap() * Balance.PIECE_COEF
	pieces_run += 1
	_ajouter_jetons(gain)
	jetons_changed.emit(jetons)
	_jetons_dirty = false
	_verifier_objectif()
	return gain

## Si une roue est en cours quand la table se termine, on la paie tout de suite.
func _payer_roue_si_besoin() -> void:
	if roue_en_cours:
		_payer_roue()

# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

func prix_upgrade(i: int) -> float:
	return Balance.prix_upgrade(i, niveaux[i])

func peut_acheter(i: int) -> bool:
	return phase == Phase.JEU and jetons >= prix_upgrade(i)

func acheter_upgrade(i: int) -> bool:
	if not peut_acheter(i):
		return false
	jetons -= prix_upgrade(i)
	niveaux[i] += 1
	jetons_changed.emit(jetons)
	upgrades_changed.emit()
	chauffe_changed.emit(chauffes, chauffe_max())
	return true

# ---------------------------------------------------------------------------
# Cartes
# ---------------------------------------------------------------------------

## Tire jusqu'a 3 cartes proposees (la Roue-dependantes sont exclues avec le Croupier muet).
func preparer_offre() -> bool:
	var pool: Array[String] = []
	for c: Dictionary in Cards.LISTE:
		var id: String = c["id"]
		if machine == "muet" and Cards.CARTES_ROUE.has(id):
			continue
		if id == "gilet":
			if vies < Balance.VIES_DEPART:
				pool.append(id)
		elif id == "plombier":
			if symboles_actifs().size() > Balance.SYMBOLES_MIN:
				pool.append(id)
		elif not has_carte(id):
			pool.append(id)
	for k in range(pool.size() - 1, 0, -1):   # melange de Fisher-Yates avec la graine de la run
		var j: int = _rng.randi_range(0, k)
		var tmp: String = pool[k]
		pool[k] = pool[j]
		pool[j] = tmp
	offre = []
	for i in mini(Balance.OFFRE_CARTES, pool.size()):
		offre.append(pool[i])
	return offre.size() > 0

func prendre_carte(id: String) -> void:
	if id == "gilet":
		vies = mini(Balance.VIES_DEPART, vies + 1)
		vies_changed.emit(vies)
	elif id != "plombier":
		cartes.append(id)
	cartes_changed.emit()
	coup_de_barre_changed.emit()

func retirer_symbole(sym: String) -> void:
	if symboles_actifs().size() > Balance.SYMBOLES_MIN and not symboles_retires.has(sym):
		symboles_retires.append(sym)

func activer_coup_de_barre() -> void:
	if phase != Phase.JEU or not has_carte("coup_barre") or not coup_dispo:
		return
	coup_dispo = false
	gel_restant = Balance.COUP_DE_BARRE_DUREE
	coup_de_barre_changed.emit()

# ---------------------------------------------------------------------------
# Objectifs, reussite, echec, fin
# ---------------------------------------------------------------------------

func contrainte_satisfaite() -> bool:
	var t: Dictionary = Tables.obtenir(table_index)
	var type: String = t["type"]
	match type:
		"fenetre":
			return contrainte_ok
		"jackpot":
			return jackpots_table >= 1
		"surchauffes":
			return surchauffes_table <= int(t["max"])
		"mult":
			return multiplicateur() >= float(t["min"])
	return true

func contrainte_progression() -> String:
	var t: Dictionary = Tables.obtenir(table_index)
	var type: String = t["type"]
	match type:
		"fenetre":
			return "%s / %s" % [fmt_compact(gain_fenetre), fmt_compact(float(t["montant"]))]
		"jackpot":
			return "%d / 1" % mini(jackpots_table, 1)
		"surchauffes":
			return "%d / %d" % [surchauffes_table, int(t["max"])]
		"mult":
			return "×%s" % ("%.2f" % multiplicateur()).replace(".", ",")
	return ""

func _verifier_objectif() -> void:
	if phase != Phase.JEU:
		return
	if jetons >= objectif() and contrainte_satisfaite():
		_reussir()

func _reussir() -> void:
	_payer_roue_si_besoin()
	if Tables.est_boss(table_index):
		bosses_run += 1
	var dernier: bool = table_index >= Tables.nombre() - 1
	table_reussie.emit(table_index)
	if dernier:
		_terminer(true)
	else:
		phase = Phase.CARTES

func _fin_du_temps() -> void:
	_payer_roue_si_besoin()
	_verifier_objectif()           # le paiement de la roue peut sauver la table
	if phase == Phase.JEU:
		_rater("Temps écoulé !")

func _rater(raison: String) -> void:
	_payer_roue_si_besoin()
	dernier_pardon = false
	if machine == "phenix" and not _phenix_utilise:
		_phenix_utilise = true
		dernier_pardon = true
		pardon_phenix.emit()
	else:
		vies -= 1
	vies_changed.emit(vies)
	table_ratee.emit(table_index, raison)
	if vies <= 0:
		_terminer(false)
	else:
		phase = Phase.TRANSITION
		_pause = Balance.PAUSE_TRANSITION

func _terminer(victoire: bool) -> void:
	phase = Phase.FINI
	var base: int = maxi(1, int(floorf(Balance.PLOMBS_COEF * pic_jetons / Balance.PLOMBS_DIV)))
	var gagnes: int = int(ceilf(float(base) * float(Balance.MISES[mise_active]["plombs"])))
	var bonus_relance: bool = relance_active
	if bonus_relance:
		gagnes = int(ceilf(float(gagnes) * Balance.RELANCE_MULT))
		relance_active = false
	gagnes += bosses_run * Balance.BOSS_PLOMBS
	if has_carte("tirelire"):
		gagnes += Balance.TIRELIRE_PLOMBS
	# defi du jour : 1re fois = bonus, puis on garde le meilleur score
	var defi_bonus: int = 0
	var defi_record: bool = false
	if defi:
		if not Save.defi_joue_aujourdhui():
			defi_bonus = Balance.DEFI_PLOMBS_PREMIER
			Save.defi_jour = Save.jour_courant()
			Save.defi_score = pic_jetons
			Save.defis_total += 1
			defi_record = true
		elif pic_jetons > Save.defi_score:
			Save.defi_score = pic_jetons
			defi_record = true
		gagnes += defi_bonus
	var atteinte: int = table_index + 1
	Save.plombs += gagnes
	Save.meilleure_table = maxi(Save.meilleure_table, atteinte)
	# statistiques + mise suivante
	Save.ajouter_stat("runs", 1)
	Save.ajouter_stat("taps", taps)
	Save.ajouter_stat("jackpots", jackpots_run)
	Save.ajouter_stat("bosses", bosses_run)
	var mise_debloquee: int = -1
	if victoire:
		Save.ajouter_stat("victoires", 1)
		if not defi and mise_active == Save.mise_max and Save.mise_max < Balance.MISES.size() - 1:
			Save.mise_max += 1
			mise_debloquee = Save.mise_max
	var ctx: Dictionary = {
		"jackpots_run": jackpots_run, "surchauffes_run": surchauffes_run, "pieces_run": pieces_run,
		"bosses_run": bosses_run, "pic": pic_jetons, "taps_run": taps,
		"table_sans_chaud": atteinte if (mode_arcade() and taps_chauds == 0) else 0,
		"victoire_vies": vies if victoire else 0,
		"victoire_mise": (mise_active + 1) if (victoire and not defi) else 0,
		"victoire": 1 if victoire else 0,
		"defi_fait": 1 if defi else 0,
	}
	var succes_debloques: Array = Save.verifier_succes(ctx)
	if not Save.tuto_fait:
		Save.tuto_fait = true
	Save.ecrire()
	dernier_resume = {
		"victoire": victoire,
		"table": atteinte,
		"tables_total": Tables.nombre(),
		"pic": pic_jetons,
		"meilleur_jackpot": meilleur_jackpot,
		"plombs_gagnes": gagnes,
		"plombs_total": Save.plombs,
		"objectif": objectif(),
		"jetons_fin": jetons,
		"manque": maxf(0.0, objectif() - jetons) if not victoire else 0.0,
		"bonus_relance": bonus_relance,
		"mise": mise_active,
		"mise_debloquee": mise_debloquee,
		"succes": succes_debloques,
		"defi": defi,
		"defi_record": defi_record,
		"defi_bonus": defi_bonus,
		"bosses": bosses_run,
	}
	run_terminee.emit(dernier_resume)
