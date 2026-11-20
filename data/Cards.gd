extends RefCounted
## Les 19 cartes de la maison (3 proposees au hasard apres chaque table reussie).
## Les effets sont appliques dans autoload/Game.gd ; ici, uniquement les donnees d'affichage.

const LISTE: Array = [
	{"id": "double_zero", "nom": "DOUBLE ZÉRO", "desc": "Un symbole de plus sur la roue (jackpot -1 poids), mais +2 de chauffe par tap."},
	{"id": "maison", "nom": "LA MAISON GAGNE", "desc": "Paiements de la roue ×2, mais chaque surchauffe coûte 10 % des jetons."},
	{"id": "plombier", "nom": "LE PLOMBIER", "desc": "Retire définitivement un symbole de la roue, au choix."},
	{"id": "rythme", "nom": "RYTHME DU CROUPIER", "desc": "Alterner les zones du levier : ×1,5. Sinon : ×0,8."},
	{"id": "coup_barre", "nom": "COUP DE BARRE", "desc": "1 fois par table : gèle la chauffe 10 s (bouton dédié)."},
	{"id": "stagiaire", "nom": "LE STAGIAIRE", "desc": "Un employé gratuit qui tape 1 fois/s, sans chauffe."},
	{"id": "fer_cheval", "nom": "FER À CHEVAL", "desc": "Sept et jackpot bien plus fréquents sur la roue."},
	{"id": "ventilo", "nom": "VENTILO", "desc": "Refroidissement +2 par seconde."},
	{"id": "tirelire", "nom": "LA TIRELIRE", "desc": "+3 plombs à la fin de la nuit, quoi qu'il arrive."},
	{"id": "pari", "nom": "LE PARI", "desc": "Tap maintenu ×5 au lieu de ×3, mais +2 de chauffe."},
	{"id": "bouclier", "nom": "LE BOUCLIER", "desc": "Annule la 1re surchauffe de chaque table."},
	{"id": "usurier", "nom": "L'USURIER", "desc": "Gains ×1,25, mais objectifs +15 %."},
	{"id": "chrono", "nom": "LE CHRONO", "desc": "+15 secondes sur chaque table."},
	{"id": "combo", "nom": "LE COMBO", "desc": "Un tap sur 10 vaut ×3."},
	{"id": "turbo", "nom": "ROUE TURBO", "desc": "La roue se lance tous les 18 taps au lieu de 25."},
	{"id": "gilet", "nom": "LE GILET", "desc": "Rend 1 cœur perdu (proposé seulement si tu en as perdu)."},
	{"id": "givre", "nom": "LE GIVRE", "desc": "Chauffe gelée pendant les 5 premières secondes de chaque table."},
	{"id": "trefle", "nom": "TRÈFLE À 4 FEUILLES", "desc": "Une roue ratée paie ×1 au lieu de ×0,3."},
	{"id": "equipe", "nom": "ÉQUIPE DE NUIT", "desc": "Tes employés rapportent ×2."},
]

# Cartes inutiles sans roue (machine « Croupier muet »).
const CARTES_ROUE: Array[String] = ["double_zero", "maison", "plombier", "fer_cheval", "turbo", "trefle"]

static func obtenir(id: String) -> Dictionary:
	for c: Dictionary in LISTE:
		if c["id"] == id:
			return c
	return {}
