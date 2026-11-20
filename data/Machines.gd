extends RefCounted
## 12 machines (meta, achetees en plombs), toutes implementees.
## Les effets sont appliques dans autoload/Game.gd (champ « machine »).
## Machine active vide ("") = machine de base, sans effet.

const LISTE: Array = [
	{"id": "bandit", "nom": "BANDIT MANCHOT", "prix": 50, "desc": "Le rouleau 1 est toujours un sept.", "ok": true},
	{"id": "vapeur", "nom": "MACHINE À VAPEUR", "prix": 120, "desc": "La chauffe ne redescend jamais. Surchauffe : verrou 3 s.", "ok": true},
	{"id": "becane", "nom": "VIEILLE BÉCANE", "prix": 200, "desc": "Multiplicateur +25 %. Surchauffe : verrou 4 s.", "ok": true},
	{"id": "distributeur", "nom": "LE DISTRIBUTEUR", "prix": 300, "desc": "Le premier jackpot de chaque table est garanti (1re roue).", "ok": true},
	{"id": "muet", "nom": "LE CROUPIER MUET", "prix": 450, "desc": "Pas de roue, mais tous les taps ×2,5.", "ok": true},
	{"id": "ruche", "nom": "LA RUCHE", "prix": 600, "desc": "3 jauges de chauffe indépendantes : tape sur celle que tu veux.", "ok": true},
	{"id": "glacon", "nom": "LE GLAÇON", "prix": 350, "desc": "Refroidissement ×2 et chauffe max +4.", "ok": true},
	{"id": "aimant", "nom": "L'AIMANT", "prix": 500, "desc": "Jackpot bien plus fréquent (3 aimants).", "ok": true},
	{"id": "banquier", "nom": "LE BANQUIER", "prix": 700, "desc": "Intérêts : +1 % de tes jetons toutes les 5 s.", "ok": true},
	{"id": "jumeaux", "nom": "LES JUMEAUX", "prix": 900, "desc": "15 % des taps comptent double, sans chauffe en plus.", "ok": true},
	{"id": "phenix", "nom": "LE PHÉNIX", "prix": 1200, "desc": "La 1re table ratée de la nuit ne coûte pas de cœur.", "ok": true},
	{"id": "reacteur", "nom": "LE RÉACTEUR", "prix": 1600, "desc": "Une surchauffe paie 10 taps d'un coup.", "ok": true},
]

static func existe(id: String) -> bool:
	for m: Dictionary in LISTE:
		if m["id"] == id:
			return true
	return false

## Machine achetable (implementee) ?
static func disponible(id: String) -> bool:
	for m: Dictionary in LISTE:
		if m["id"] == id:
			return bool(m["ok"])
	return false

static func obtenir(id: String) -> Dictionary:
	for m: Dictionary in LISTE:
		if m["id"] == id:
			return m
	return {}
