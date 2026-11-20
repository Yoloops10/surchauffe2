extends RefCounted
## Succes : chacun donne des plombs une seule fois. Evalues en fin de run (Save.verifier_succes).
## « cle » = valeur lue dans le contexte (stats de la run + totaux de la sauvegarde), « min » = seuil.
## Cles de run : jackpots_run, surchauffes_run, pieces_run, bosses_run, pic, taps_run,
##   table_sans_chaud (table atteinte si 0 zone chaude en ARCADE, sinon 0), victoire_vies (cœurs restants si victoire),
##   victoire_mise (numero de mise si victoire), victoire (0/1), defi_fait (0/1).
## Cles totales : t_runs, t_victoires, t_taps, t_jackpots, t_bosses, nb_machines, serie_max.

const LISTE: Array = [
	{"id": "premiere", "nom": "PREMIÈRE NUIT", "desc": "Termine une partie.", "cle": "t_runs", "min": 1, "plombs": 2},
	{"id": "jackpot1", "nom": "JACKPOT !", "desc": "Déclenche un jackpot.", "cle": "jackpots_run", "min": 1, "plombs": 2},
	{"id": "jackpot10", "nom": "FIÈVRE DU JACKPOT", "desc": "10 jackpots dans une même run.", "cle": "jackpots_run", "min": 10, "plombs": 10},
	{"id": "pyro", "nom": "PYROMANE", "desc": "10 surchauffes dans une même run.", "cle": "surchauffes_run", "min": 10, "plombs": 5},
	{"id": "sang_froid", "nom": "SANG-FROID", "desc": "Atteins la table 4 sans jamais toucher la zone chaude (Arcade).", "cle": "table_sans_chaud", "min": 4, "plombs": 6},
	{"id": "pieces", "nom": "CHASSEUR DE PIÈCES", "desc": "Ramasse 5 pièces d'or dans une run.", "cle": "pieces_run", "min": 5, "plombs": 4},
	{"id": "boss1", "nom": "TUEUR DE BOSS", "desc": "Bats un boss.", "cle": "t_bosses", "min": 1, "plombs": 5},
	{"id": "boss3", "nom": "TOUS LES BOSS", "desc": "Bats les 3 boss dans une même run.", "cle": "bosses_run", "min": 3, "plombs": 15},
	{"id": "million", "nom": "MILLIONNAIRE", "desc": "Atteins 1 M de jetons dans une run.", "cle": "pic", "min": 1000000, "plombs": 3},
	{"id": "cent_m", "nom": "CASINO RUINÉ", "desc": "Atteins 100 M de jetons dans une run.", "cle": "pic", "min": 100000000, "plombs": 10},
	{"id": "victoire", "nom": "NUIT BLANCHE", "desc": "Gagne une nuit complète.", "cle": "t_victoires", "min": 1, "plombs": 15},
	{"id": "parfait", "nom": "SANS UNE ÉGRATIGNURE", "desc": "Gagne en gardant tes 3 cœurs.", "cle": "victoire_vies", "min": 3, "plombs": 20},
	{"id": "haute_mise", "nom": "JOUEUR DE HAUT VOL", "desc": "Gagne à la mise 3 ou plus.", "cle": "victoire_mise", "min": 3, "plombs": 25},
	{"id": "collection", "nom": "COLLECTIONNEUR", "desc": "Possède 3 machines.", "cle": "nb_machines", "min": 3, "plombs": 10},
	{"id": "serie7", "nom": "FIDÈLE AU POSTE", "desc": "Atteins une série de 7 jours.", "cle": "serie_max", "min": 7, "plombs": 10},
	{"id": "defi", "nom": "DÉFI RELEVÉ", "desc": "Termine un défi du jour.", "cle": "defi_fait", "min": 1, "plombs": 3},
	{"id": "taps1000", "nom": "DOIGTS D'OR", "desc": "1 000 taps au total.", "cle": "t_taps", "min": 1000, "plombs": 5},
	{"id": "taps10000", "nom": "TENDINITE", "desc": "10 000 taps au total.", "cle": "t_taps", "min": 10000, "plombs": 20},
]

static func obtenir(id: String) -> Dictionary:
	for s: Dictionary in LISTE:
		if s["id"] == id:
			return s
	return {}
