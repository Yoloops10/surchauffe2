extends Node
## Sauvegarde locale user://save.json (aucun reseau). Tolerante aux fichiers corrompus :
## tout champ invalide retombe sur sa valeur par defaut.

const Machines = preload("res://data/Machines.gd")
const Balance = preload("res://data/Balance.gd")
const Succes = preload("res://data/Succes.gd")
const Tables = preload("res://data/Tables.gd")

const CHEMIN: String = "user://save.json"
const VERSION: int = 2

var plombs: int = 0
var machines_achetees: Array[String] = []
var machine_active: String = ""   # "" = machine de base
var meilleure_table: int = 0
var mute: bool = false
var serie: int = 0              # jours consecutifs
var dernier_jour: int = -1      # dernier jour ou le bonus a ete reclame
var serie_max: int = 0
var mode: String = "arcade"     # "arcade" (rapide, bonus fun) ou "classique" (version d'origine, plus lente)
var mise: int = 0               # mise choisie (index dans Balance.MISES)
var mise_max: int = 0           # plus haute mise debloquee
var tuto_fait: bool = false     # tutoriel de la 1re partie termine
var succes: Array[String] = []  # ids des succes debloques
var stats: Dictionary = {}      # totaux : runs, victoires, taps, jackpots, bosses
var defi_jour: int = -1         # jour du dernier defi joue
var defi_score: float = 0.0     # meilleur score (pic de jetons) du defi de ce jour
var defis_total: int = 0

func _ready() -> void:
	charger()

func _defauts() -> void:
	plombs = 0
	machines_achetees = []
	machine_active = ""
	meilleure_table = 0
	mute = false
	serie = 0
	dernier_jour = -1
	serie_max = 0
	mode = "arcade"
	mise = 0
	mise_max = 0
	tuto_fait = false
	succes = []
	stats = {}
	defi_jour = -1
	defi_score = 0.0
	defis_total = 0

## Convertit une valeur JSON en entier (0 si ce n'est pas un nombre).
func _vers_int(v: Variant, defaut: int = 0) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return defaut

func charger() -> void:
	_defauts()
	if not FileAccess.file_exists(CHEMIN):
		return
	var f: FileAccess = FileAccess.open(CHEMIN, FileAccess.READ)
	if f == null:
		return
	var texte: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(texte) != OK:
		return   # fichier corrompu : on garde les valeurs par defaut
	var brut: Variant = json.data
	if typeof(brut) != TYPE_DICTIONARY:
		return
	var d: Dictionary = brut
	plombs = maxi(0, _vers_int(d.get("plombs", 0)))
	meilleure_table = clampi(_vers_int(d.get("meilleure_table", 0)), 0, Tables.nombre())
	mute = d.get("mute", false) == true
	serie = maxi(0, _vers_int(d.get("serie", 0)))
	dernier_jour = _vers_int(d.get("dernier_jour", -1), -1)
	serie_max = maxi(serie, _vers_int(d.get("serie_max", 0)))
	mode = "classique" if str(d.get("mode", "arcade")) == "classique" else "arcade"
	mise_max = clampi(_vers_int(d.get("mise_max", 0)), 0, Balance.MISES.size() - 1)
	mise = clampi(_vers_int(d.get("mise", 0)), 0, mise_max)
	tuto_fait = d.get("tuto_fait", false) == true
	defi_jour = _vers_int(d.get("defi_jour", -1), -1)
	defi_score = maxf(0.0, float(_vers_int(d.get("defi_score", 0))))
	defis_total = maxi(0, _vers_int(d.get("defis_total", 0)))
	var ls: Variant = d.get("succes", [])
	if typeof(ls) == TYPE_ARRAY:
		for v: Variant in ls:
			if typeof(v) == TYPE_STRING and not Succes.obtenir(str(v)).is_empty() and not succes.has(str(v)):
				succes.append(str(v))
	var st: Variant = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k: Variant in (st as Dictionary).keys():
			stats[str(k)] = maxi(0, _vers_int((st as Dictionary)[k]))
	var liste: Variant = d.get("machines_achetees", [])
	if typeof(liste) == TYPE_ARRAY:
		for id_v: Variant in liste:
			if typeof(id_v) == TYPE_STRING:
				var id: String = id_v
				if Machines.existe(id) and not machines_achetees.has(id):
					machines_achetees.append(id)
	var actif: Variant = d.get("machine_active", "")
	if typeof(actif) == TYPE_STRING:
		var a: String = actif
		if a != "" and machines_achetees.has(a):
			machine_active = a

func ecrire() -> void:
	var d: Dictionary = {
		"plombs": plombs,
		"machines_achetees": machines_achetees,
		"machine_active": machine_active,
		"meilleure_table": meilleure_table,
		"mute": mute,
		"serie": serie,
		"dernier_jour": dernier_jour,
		"serie_max": serie_max,
		"mode": mode,
		"mise": mise,
		"mise_max": mise_max,
		"tuto_fait": tuto_fait,
		"succes": succes,
		"stats": stats,
		"defi_jour": defi_jour,
		"defi_score": defi_score,
		"defis_total": defis_total,
		"version": VERSION,
	}
	var tmp: String = CHEMIN + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save : impossible d'ecrire la sauvegarde")
		return
	f.store_string(JSON.stringify(d))
	f.close()
	# ecriture atomique : on remplace le fichier une fois le temporaire complet
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("save.json"):
			dir.remove("save.json")
		dir.rename("save.json.tmp", "save.json")

func effacer() -> void:
	_defauts()
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and dir.file_exists("save.json"):
		dir.remove("save.json")
	ecrire()

func possede(id: String) -> bool:
	return machines_achetees.has(id)

# ---------------------------------------------------------------------------
# Retention : serie quotidienne et offre flash (horloge locale, aucun reseau)
# ---------------------------------------------------------------------------

func _maintenant() -> float:
	return Time.get_unix_time_from_system()

func jour_courant() -> int:
	return int(floorf(_maintenant() / 86400.0))

## Secondes avant la fin du jour (= avant que la serie ne soit perdue).
func secondes_avant_perte() -> float:
	return 86400.0 - fmod(_maintenant(), 86400.0)

## Apercu du bonus du jour sans rien modifier. Vide si deja reclame aujourd'hui.
## Renvoie { serie, recompense, perdue } (perdue > 0 : une serie vient d'etre cassee).
func apercu_serie() -> Dictionary:
	var j: int = jour_courant()
	if dernier_jour == j:
		return {}
	var nouvelle: int = 1
	var perdue: int = 0
	if dernier_jour >= 0 and j - dernier_jour == 1:
		nouvelle = serie + 1
	elif dernier_jour >= 0:
		perdue = serie
	var liste: Array[int] = Balance.SERIE_RECOMPENSES
	return {"serie": nouvelle, "recompense": liste[(nouvelle - 1) % liste.size()], "perdue": perdue}

## Reclame le bonus du jour. Renvoie le nombre de plombs gagnes (0 si deja reclame).
func reclamer_serie() -> int:
	var a: Dictionary = apercu_serie()
	if a.is_empty():
		return 0
	serie = int(a["serie"])
	serie_max = maxi(serie_max, serie)
	dernier_jour = jour_courant()
	plombs += int(a["recompense"])
	ecrire()
	return int(a["recompense"])

func set_mode(m: String) -> void:
	mode = "classique" if m == "classique" else "arcade"
	ecrire()

func serie_active_aujourdhui() -> bool:
	return dernier_jour == jour_courant()

## Offre flash en cours : { id, reste (s), remise } ; vide si tout est deja achete.
func offre_flash() -> Dictionary:
	var candidats: Array[String] = []
	for m: Dictionary in Machines.LISTE:
		if bool(m["ok"]) and not possede(str(m["id"])):
			candidats.append(str(m["id"]))
	if candidats.is_empty():
		return {}
	var t: float = _maintenant()
	var fenetre: int = int(floorf(t / Balance.OFFRE_FENETRE_S))
	return {
		"id": candidats[fenetre % candidats.size()],
		"reste": Balance.OFFRE_FENETRE_S - fmod(t, Balance.OFFRE_FENETRE_S),
		"remise": Balance.OFFRE_REMISE,
	}

## Prix reel d'une machine (remise de l'offre flash incluse).
func prix_machine(id: String) -> int:
	var base: int = int(Machines.obtenir(id).get("prix", 0))
	var o: Dictionary = offre_flash()
	if not o.is_empty() and o["id"] == id:
		return maxi(1, roundi(float(base) * (1.0 - float(o["remise"]))))
	return base

## Achat d'une machine en plombs. Renvoie true si l'achat est fait.
func acheter(id: String) -> bool:
	if not Machines.disponible(id) or possede(id):
		return false
	var m: Dictionary = Machines.obtenir(id)
	var prix: int = prix_machine(id)
	if plombs < prix:
		return false
	plombs -= prix
	machines_achetees.append(id)
	ecrire()
	return true

## Equipe une machine possedee ("" = machine de base).
func equiper(id: String) -> void:
	if id == "" or possede(id):
		machine_active = id
		ecrire()

func set_mute(valeur: bool) -> void:
	mute = valeur
	ecrire()

# ---------------------------------------------------------------------------
# Mises, statistiques, succes, defi du jour
# ---------------------------------------------------------------------------

func set_mise(m: int) -> void:
	mise = clampi(m, 0, mise_max)
	ecrire()

func stat(cle: String) -> int:
	return int(stats.get(cle, 0))

func ajouter_stat(cle: String, n: int) -> void:
	stats[cle] = stat(cle) + n

## Evalue tous les succes avec le contexte de la run (ctx) + les totaux. Les nouveaux succes
## donnent leurs plombs tout de suite. Renvoie la liste des succes debloques (dictionnaires).
func verifier_succes(ctx: Dictionary) -> Array:
	var c: Dictionary = ctx.duplicate()
	c["t_runs"] = stat("runs")
	c["t_victoires"] = stat("victoires")
	c["t_taps"] = stat("taps")
	c["t_jackpots"] = stat("jackpots")
	c["t_bosses"] = stat("bosses")
	c["nb_machines"] = machines_achetees.size()
	c["serie_max"] = serie_max
	var nouveaux: Array = []
	for sc: Dictionary in Succes.LISTE:
		var id: String = str(sc["id"])
		if succes.has(id):
			continue
		if float(c.get(str(sc["cle"]), 0.0)) >= float(sc["min"]):
			succes.append(id)
			plombs += int(sc["plombs"])
			nouveaux.append(sc)
	return nouveaux

## Defi d'aujourd'hui : modificateur et graine dependent du numero du jour.
func defi_modificateur() -> Dictionary:
	return Balance.DEFI_MODIFS[jour_courant() % Balance.DEFI_MODIFS.size()]

func defi_graine() -> int:
	return jour_courant() * 7919 + 13

func defi_joue_aujourdhui() -> bool:
	return defi_jour == jour_courant()

func meilleur_score_defi() -> float:
	return defi_score if defi_joue_aujourdhui() else 0.0
