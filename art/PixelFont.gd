extends RefCounted
## Police pixel 5x7 generee en code (FontFile sans fichier). Majuscules uniquement :
## les minuscules et les lettres accentuees reutilisent les glyphes majuscules.
## Taille de base 8 px ; tailles 16 et 32 = mise a l'echelle ENTIERE x2 / x4 (pixels nets).

const BASE: int = 8
const HAUT: int = 12          # hauteur d'une cellule : 2 lignes d'accent, 1 de vide, 7 de lettre, 1 de cedille
const LIGNE0: int = 3         # premiere ligne de la lettre dans la cellule
const ASCENT: float = 10.0    # la ligne de base est apres la ligne 9
const DESCENT: float = 1.0

static var _police: FontFile = null

const G: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".####", "#....", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..###", "....#", "....#", "....#", "....#", "#...#", ".###."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	".": [".", ".", ".", ".", ".", ".", "#"],
	",": ["..", "..", "..", "..", ".#", ".#", "#."],
	":": [".", ".", "#", ".", ".", "#", "."],
	";": ["..", "..", ".#", "..", "..", ".#", "#."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"'": ["#", "#", ".", ".", ".", ".", "."],
	"\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
	"-": [".....", ".....", ".....", "####.", ".....", ".....", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"\\": ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
	"|": ["#", "#", "#", "#", "#", "#", "#"],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	"<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
	">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
	"×": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."],
	"≥": ["#....", ".#...", "..#..", ".#...", "#....", ".....", "#####"],
	"…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
	"«": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
	"»": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
	"Œ": [".##.###", "#..##..", "#..###.", "#..##..", "#..##..", "#..##..", ".##.###"],
}

# Lettres accentuees : [lettre de base, accent, cedille]
const ACCENTS: Dictionary = {
	"À": ["A", "grave"], "Â": ["A", "circ"], "Ä": ["A", "trema"],
	"È": ["E", "grave"], "É": ["E", "aigu"], "Ê": ["E", "circ"], "Ë": ["E", "trema"],
	"Î": ["I", "circ"], "Ï": ["I", "trema"],
	"Ô": ["O", "circ"], "Ö": ["O", "trema"],
	"Ù": ["U", "grave"], "Û": ["U", "circ"], "Ü": ["U", "trema"],
	"Ç": ["C", "cedille"],
}

# Minuscules -> glyphe majuscule
const MINUSCULES: Dictionary = {
	"à": "À", "â": "Â", "ä": "Ä", "è": "È", "é": "É", "ê": "Ê", "ë": "Ë", "î": "Î", "ï": "Ï",
	"ô": "Ô", "ö": "Ö", "ù": "Ù", "û": "Û", "ü": "Ü", "ç": "Ç", "œ": "Œ", "’": "'",
}

static func police() -> FontFile:
	if _police == null:
		_police = _construire()
	return _police

## Lignes ('#' / '.') d'un caractere dans une cellule de HAUT lignes, accents compris.
static func _cellule(c: String) -> Array:
	var haut: Array = []
	var base: String = c
	var accent: String = ""
	if ACCENTS.has(c):
		base = ACCENTS[c][0]
		accent = ACCENTS[c][1]
	var lignes: Array = G[base]
	var w: int = String(lignes[0]).length()
	var vide: String = ".".repeat(w)
	for i in HAUT:
		haut.append(vide)
	for i in 7:
		haut[LIGNE0 + i] = lignes[i]
	match accent:
		"aigu":
			haut[0] = "...#." if w >= 5 else vide
			haut[1] = "..#.." if w >= 5 else vide
		"grave":
			haut[0] = ".#..." if w >= 5 else vide
			haut[1] = "..#.." if w >= 5 else vide
		"circ":
			haut[0] = "..#.." if w >= 5 else ".#."
			haut[1] = ".#.#." if w >= 5 else "#.#"
		"trema":
			haut[1] = ".#.#." if w >= 5 else "#.#"
		"cedille":
			haut[LIGNE0 + 7] = "..#.." if w >= 5 else vide
	return haut

static func _construire() -> FontFile:
	var cles: Array = G.keys()
	for c: String in ACCENTS.keys():
		cles.append(c)
	# atlas : une ligne de glyphes separes d'une colonne vide
	var cells: Dictionary = {}
	var largeur_totale: int = 0
	for c: String in cles:
		var cel: Array = _cellule(c)
		cells[c] = cel
		largeur_totale += String(cel[0]).length() + 1
	var img: Image = Image.create(largeur_totale, HAUT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var f: FontFile = FontFile.new()
	f.fixed_size = BASE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	var taille: Vector2i = Vector2i(BASE, 0)
	var x: int = 0
	var infos: Dictionary = {}   # caractere -> [largeur, x dans l'atlas]
	for c: String in cles:
		var cel: Array = cells[c]
		var w: int = String(cel[0]).length()
		for yy in HAUT:
			var ligne: String = cel[yy]
			for xx in w:
				if ligne[xx] == "#":
					img.set_pixel(x + xx, yy, Color.WHITE)
		infos[c] = [w, x]
		_declarer(f, c.unicode_at(0), w, x)
		x += w + 1
	f.set_texture_image(0, taille, 0, img)
	f.set_cache_ascent(0, BASE, ASCENT)
	f.set_cache_descent(0, BASE, DESCENT)
	# espace
	f.set_glyph_advance(0, BASE, 32, Vector2(4.0, 0.0))
	# minuscules : meme glyphe que la majuscule (l'index de glyphe d'une police bitmap = code Unicode)
	for k: String in MINUSCULES.keys():
		var src: Array = infos[String(MINUSCULES[k])]
		_declarer(f, k.unicode_at(0), int(src[0]), int(src[1]))
	for i in 26:
		var src2: Array = infos[char(65 + i)]
		_declarer(f, 97 + i, int(src2[0]), int(src2[1]))
	return f

static func _declarer(f: FontFile, idx: int, w: int, x: int) -> void:
	var taille: Vector2i = Vector2i(BASE, 0)
	f.set_glyph_advance(0, BASE, idx, Vector2(float(w + 1), 0.0))
	f.set_glyph_offset(0, taille, idx, Vector2(0.0, -ASCENT))
	f.set_glyph_size(0, taille, idx, Vector2(float(w), float(HAUT)))
	f.set_glyph_uv_rect(0, taille, idx, Rect2(float(x), 0.0, float(w), float(HAUT)))
	f.set_glyph_texture_idx(0, taille, idx, 0)
