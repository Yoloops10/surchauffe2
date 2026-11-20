extends RefCounted
## Les 10 tables d'une nuit (dont 3 BOSS : champ « boss »). L'objectif est un nombre de jetons DETENUS (cumul de la run).
## Types de contrainte : aucune | fenetre | jackpot | surchauffes | mult | chaud (boss) | sans_roue (boss)

const Balance = preload("res://data/Balance.gd")

const LISTE: Array = [
	{"objectif": 2500.0, "duree": Balance.DUREE_TABLE, "type": "aucune"},
	{"objectif": 12000.0, "duree": Balance.DUREE_TABLE, "type": "aucune"},
	# Table 3 : encaisser 20 000 jetons sur une fenetre glissante de 20 s (verrou une fois atteint).
	{"objectif": 60000.0, "duree": Balance.DUREE_TABLE, "type": "fenetre", "montant": 20000.0, "fenetre": 20.0},
	# BOSS 1 : zero surchauffe toleree.
	{"objectif": 110000.0, "duree": 70.0, "type": "surchauffes", "max": 0, "boss": "LE VIGILE"},
	{"objectif": 250000.0, "duree": Balance.DUREE_TABLE, "type": "jackpot"},
	# La 3e surchauffe fait rater la table immediatement.
	{"objectif": 1200000.0, "duree": Balance.DUREE_TABLE, "type": "surchauffes", "max": 2},
	# BOSS 2 : la chauffe maximale est divisee par deux.
	{"objectif": 2400000.0, "duree": 80.0, "type": "chaud", "boss": "LE GIVRE"},
	# Le multiplicateur doit etre >= x3 au moment ou l'objectif est franchi.
	{"objectif": 5000000.0, "duree": Balance.DUREE_TABLE, "type": "mult", "min": Balance.MULT_MIN_TABLE_6},
	# BOSS 3 : pas de roue, uniquement des taps.
	{"objectif": 7000000.0, "duree": 70.0, "type": "sans_roue", "boss": "LE CROUPIER MUET"},
	{"objectif": 25000000.0, "duree": Balance.DUREE_TABLE_FINALE, "type": "aucune"},
]

static func nombre() -> int:
	return LISTE.size()

static func obtenir(i: int) -> Dictionary:
	return LISTE[clampi(i, 0, LISTE.size() - 1)]

static func est_boss(i: int) -> bool:
	return obtenir(i).has("boss")

## Texte de contrainte (sans la progression), en francais.
static func texte_contrainte(i: int) -> String:
	var t: Dictionary = obtenir(i)
	var type: String = t["type"]
	var pre: String = ("BOSS %s : " % str(t["boss"])) if t.has("boss") else ""
	match type:
		"chaud":
			return pre + "chauffe max ÷ 2"
		"sans_roue":
			return pre + "pas de roue, que des taps"
		"fenetre":
			return "Encaisser %s jetons en %d s" % ["20 000", int(t["fenetre"])]
		"jackpot":
			return "Déclencher au moins 1 jackpot"
		"surchauffes":
			if int(t["max"]) == 0:
				return pre + "aucune surchauffe"
			return "Pas plus de %d surchauffes" % int(t["max"])
		"mult":
			return "Finir avec un multiplicateur ≥ ×3"
	if i == LISTE.size() - 1:
		return "Table finale : %d s" % int(t["duree"])
	return "Aucune contrainte"
