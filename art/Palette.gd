extends RefCounted
## Palette imposee : 8 couleurs, rien d'autre n'est autorise dans le jeu.
## Lettres des cartes ASCII : a..h = index 0..7 ; '.' = transparent.

const ENCRE := Color("#140f1b")    # a
const PRUNE := Color("#2b1b3d")    # b
const ROUGE := Color("#e8453c")    # c
const ORANGE := Color("#ff8a3d")   # d
const DORE := Color("#ffd166")     # e (« or »)
const CREME := Color("#f5e6c8")    # f
const VERT := Color("#3ecf8e")     # g
const GRIS := Color("#6b6076")     # h

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

## Couleur d'une lettre de carte ASCII ('.' ou inconnu => transparent).
static func couleur(lettre: String) -> Color:
	match lettre:
		"a": return ENCRE
		"b": return PRUNE
		"c": return ROUGE
		"d": return ORANGE
		"e": return DORE
		"f": return CREME
		"g": return VERT
		"h": return GRIS
	return TRANSPARENT
