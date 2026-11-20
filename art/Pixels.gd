extends RefCounted
## Pixel art genere en code : cartes ASCII -> Image -> ImageTexture.
## Lettres : '.' transparent, 'a'..'h' = palette (voir Palette.gd).
## Tous les sprites sont rendus a une echelle PAIRE (grille de 2 px minimum).

const Pal = preload("res://art/Palette.gd")
const PixelFont = preload("res://art/PixelFont.gd")

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _cache: Dictionary = {}
static var _styles: Dictionary = {}

# Police 5x7 pour le titre (seules les lettres de SURCHAUFFE sont necessaires).
const FONTE: Dictionary = {
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
}

const SYMBOLES: Array[String] = ["cerise", "citron", "cloche", "sept", "jackpot", "zero"]
const CARTES_ICONES: Array[String] = ["double_zero", "maison", "plombier", "rythme", "coup_barre", "stagiaire",
	"fer_cheval", "ventilo", "tirelire", "pari", "bouclier", "usurier", "chrono", "combo", "turbo", "gilet", "givre", "trefle", "equipe"]

# ---------------------------------------------------------------------------
# Conversion carte ASCII -> Image / ImageTexture
# ---------------------------------------------------------------------------

## Carte ASCII -> Image RGBA (chaque pixel de la carte devient scale x scale).
## swap : remplacement de lettres a la volee (ex. {"d": "e"}).
static func image(map: PackedStringArray, scale: int = 2, swap: Dictionary = {}) -> Image:
	var h: int = map.size()
	var w: int = 1
	for ligne: String in map:
		w = maxi(w, ligne.length())
	var img: Image = Image.create(maxi(1, w * scale), maxi(1, h * scale), false, Image.FORMAT_RGBA8)
	img.fill(Pal.TRANSPARENT)
	for y in h:
		var ligne: String = map[y]
		for x in ligne.length():
			var lettre: String = ligne[x]
			if swap.has(lettre):
				lettre = swap[lettre]
			var c: Color = Pal.couleur(lettre)
			if c.a <= 0.0:
				continue
			for sy in scale:
				for sx in scale:
					img.set_pixel(x * scale + sx, y * scale + sy, c)
	return img

## Fonction demandee par le cahier des charges : carte ASCII -> ImageTexture.
static func make(map: PackedStringArray, scale: int = 2, swap: Dictionary = {}) -> ImageTexture:
	return ImageTexture.create_from_image(image(map, scale, swap))

# ---------------------------------------------------------------------------
# Petit atelier de dessin sur grille de caracteres
# ---------------------------------------------------------------------------

static func _grille(w: int, h: int) -> Array:
	var g: Array = []
	for y in h:
		var ligne: Array = []
		for x in w:
			ligne.append(".")
		g.append(ligne)
	return g

static func _lire(g: Array, x: int, y: int) -> String:
	if y < 0 or y >= g.size():
		return "."
	var ligne: Array = g[y]
	if x < 0 or x >= ligne.size():
		return "."
	return ligne[x]

static func _p(g: Array, x: int, y: int, c: String) -> void:
	if y < 0 or y >= g.size():
		return
	var ligne: Array = g[y]
	if x < 0 or x >= ligne.size():
		return
	ligne[x] = c

static func _rect(g: Array, x: int, y: int, w: int, h: int, c: String) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_p(g, xx, yy, c)

## Disque ; cx, cy en coordonnees « bord de pixel » (le centre du pixel x est x + 0.5).
static func _disque(g: Array, cx: float, cy: float, r: float, c: String) -> void:
	var h: int = g.size()
	var w: int = (g[0] as Array).size()
	for y in h:
		for x in w:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				_p(g, x, y, c)

## Anneau elliptique : dans l'ellipse (rx, ry) mais hors de l'ellipse interieure (rxi, ryi).
static func _anneau(g: Array, cx: float, cy: float, rx: float, ry: float, rxi: float, ryi: float, c: String) -> void:
	var h: int = g.size()
	var w: int = (g[0] as Array).size()
	for y in h:
		for x in w:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			var ext: float = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
			var inte: float = (dx * dx) / (rxi * rxi) + (dy * dy) / (ryi * ryi)
			if ext <= 1.0 and inte > 1.0:
				_p(g, x, y, c)

static func _ellipse(g: Array, cx: float, cy: float, rx: float, ry: float, c: String) -> void:
	var h: int = g.size()
	var w: int = (g[0] as Array).size()
	for y in h:
		for x in w:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0:
				_p(g, x, y, c)

static func _ligne(g: Array, x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		_p(g, x, y, c)
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

## Contour noir 1 px autour de tout ce qui n'est pas transparent.
static func _contour(g: Array, c: String = "a") -> void:
	var h: int = g.size()
	var w: int = (g[0] as Array).size()
	var a_poser: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _lire(g, x, y) != ".":
				continue
			for d: Vector2i in DIRS4:
				if _lire(g, x + d.x, y + d.y) != ".":
					a_poser.append(Vector2i(x, y))
					break
	for v: Vector2i in a_poser:
		_p(g, v.x, v.y, c)

static func _vers_map(g: Array) -> PackedStringArray:
	var sortie: PackedStringArray = PackedStringArray()
	for ligne_v in g:
		var ligne: Array = ligne_v
		sortie.append("".join(PackedStringArray(ligne)))
	return sortie

# ---------------------------------------------------------------------------
# Cartes des sprites
# ---------------------------------------------------------------------------

## Symboles de rouleau, 16x16.
static func map_symbole(id: String) -> PackedStringArray:
	var g: Array = _grille(16, 16)
	match id:
		"cerise":
			_ligne(g, 5, 8, 9, 2, "g")
			_ligne(g, 11, 8, 9, 2, "g")
			_disque(g, 11.5, 3.6, 2.2, "g")
			_disque(g, 5.0, 11.0, 3.7, "c")
			_disque(g, 11.0, 11.5, 3.7, "c")
			_p(g, 3, 9, "f")
			_p(g, 9, 10, "f")
			_p(g, 6, 13, "a")
			_p(g, 12, 14, "a")
		"citron":
			_ellipse(g, 8.0, 8.8, 6.6, 4.6, "e")
			_p(g, 1, 8, "e")
			_p(g, 14, 8, "e")
			for y in range(9, 14):
				for x in range(3, 15):
					if _lire(g, x, y) == "e":
						var nx: float = (float(x) + 0.5 - 8.0) / 6.6
						var ny: float = (float(y) + 0.5 - 8.8) / 4.6
						if nx * nx + ny * ny > 0.55 and nx > -0.2:
							_p(g, x, y, "d")
			_rect(g, 4, 6, 3, 1, "f")
			_p(g, 3, 7, "f")
			_disque(g, 11.0, 3.4, 1.9, "g")
			_ligne(g, 10, 5, 9, 6, "g")
		"cloche":
			var demi: Array[int] = [2, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7]
			for i in demi.size():
				var y: int = 2 + i
				_rect(g, 8 - demi[i], y, demi[i] * 2, 1, "e")
			_rect(g, 1, 12, 14, 1, "d")
			_disque(g, 8.0, 1.8, 1.3, "e")
			_disque(g, 8.0, 13.8, 1.6, "d")
			_rect(g, 5, 4, 1, 6, "f")
			_rect(g, 11, 6, 2, 5, "d")
		"sept":
			_rect(g, 3, 2, 11, 3, "c")
			for dx in range(-1, 2):
				_ligne(g, 12 + dx, 4, 6 + dx, 14, "c")
			_rect(g, 3, 2, 11, 1, "f")
			_rect(g, 12, 4, 1, 2, "d")
		"jackpot":
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_ligne(g, 8, 8, 8 + d.x * 7, 8 + d.y * 7, "e")
				_ligne(g, 7, 7, 7 + d.x * 6, 7 + d.y * 6, "e")
			for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				_ligne(g, 8, 8, 8 + d.x * 5, 8 + d.y * 5, "e")
			_disque(g, 8.0, 8.0, 4.8, "e")
			_disque(g, 8.0, 8.0, 3.2, "d")
			_disque(g, 8.0, 8.0, 1.6, "f")
		"zero":
			_anneau(g, 4.8, 8.0, 3.8, 5.8, 1.7, 3.6, "g")
			_anneau(g, 11.2, 8.0, 3.8, 5.8, 1.7, 3.6, "g")
			_p(g, 3, 4, "f")
			_p(g, 9, 4, "f")
	_contour(g)
	return _vers_map(g)

## Coeur de vie (plein ou vide), 14x13.
static func map_coeur(plein: bool) -> PackedStringArray:
	var g: Array = _grille(14, 13)
	var rempli: String = "c" if plein else "b"
	_disque(g, 4.8, 4.8, 3.6, rempli)
	_disque(g, 9.2, 4.8, 3.6, rempli)
	for y in range(5, 12):
		var demi: float = 6.3 - float(y - 5) * 0.9
		for x in 14:
			if absf(float(x) + 0.5 - 7.0) <= demi:
				_p(g, x, y, rempli)
	if plein:
		_p(g, 3, 3, "f")
		_p(g, 4, 3, "f")
		_p(g, 3, 4, "f")
	_contour(g, "a" if plein else "h")
	return _vers_map(g)

## Levier 16x28 : haut ou tire.
static func map_levier(bas: bool) -> PackedStringArray:
	var g: Array = _grille(16, 28)
	var by: int = 15 if bas else 6
	_rect(g, 7, by, 3, 23 - by, "h")
	_rect(g, 7, by, 1, 23 - by, "f")
	_rect(g, 2, 22, 12, 4, "h")
	_rect(g, 2, 22, 12, 1, "f")
	_rect(g, 2, 25, 12, 1, "b")
	_disque(g, 8.5, float(by) + 0.5, 5.4, "c")
	_p(g, 6, by - 2, "f")
	_p(g, 7, by - 3, "f")
	_p(g, 6, by - 1, "f")
	_rect(g, 10, by + 1, 2, 3, "a")
	_contour(g)
	return _vers_map(g)

## Carcasse de la machine : 88x64 (echelle 4 => 352x256).
## Fenetre des rouleaux : interieur x 12..75, y 18..49 ; cellules de 20 px a partir de x = 14.
static func map_carcasse() -> PackedStringArray:
	var g: Array = _grille(88, 64)
	_rect(g, 1, 1, 86, 62, "c")
	# coins arrondis
	for k in 3:
		for j in (3 - k):
			_p(g, 1 + j, 1 + k, ".")
			_p(g, 86 - j, 1 + k, ".")
			_p(g, 1 + j, 62 - k, ".")
			_p(g, 86 - j, 62 - k, ".")
	# relief : reflet haut / ombre 2 px bas
	_rect(g, 4, 2, 80, 1, "f")
	_rect(g, 3, 61, 82, 2, "a")
	# anneau neon orange
	_rect(g, 3, 3, 82, 1, "d")
	_rect(g, 3, 60, 82, 1, "d")
	_rect(g, 3, 3, 1, 58, "d")
	_rect(g, 84, 3, 1, 58, "d")
	# bandeau enseigne
	_rect(g, 8, 6, 72, 9, "a")
	_rect(g, 9, 7, 70, 7, "b")
	# fenetre des rouleaux
	_rect(g, 11, 17, 66, 34, "a")
	_rect(g, 12, 18, 64, 32, "b")
	_rect(g, 34, 18, 1, 32, "h")
	_rect(g, 54, 18, 1, 32, "h")
	_rect(g, 12, 18, 64, 1, "h")
	# plateau (compteur de la roue)
	_rect(g, 22, 53, 44, 6, "a")
	_rect(g, 23, 54, 42, 4, "b")
	# vis
	for p: Vector2i in [Vector2i(6, 18), Vector2i(81, 18), Vector2i(6, 50), Vector2i(81, 50)]:
		_rect(g, p.x, p.y, 2, 2, "e")
	_contour(g)
	return _vers_map(g)

## Bouton / panneau extensible en 9-slice : 12x12 (marges de 4 px de carte).
static func map_bouton() -> PackedStringArray:
	return PackedStringArray([
		"..aaaaaaaa..",
		".adddddddda.",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		"adbbbbbbbbda",
		".adddddddda.",
		"..aaaaaaaa..",
	])

## Ampoule neon 4x4.
static func map_ampoule() -> PackedStringArray:
	return PackedStringArray([
		".ee.",
		"effe",
		"eeee",
		".ee.",
	])

## Icones des cartes de la maison, 12x12.
static func map_icone(id: String) -> PackedStringArray:
	var g: Array = _grille(14, 14)
	match id:
		"double_zero":
			_anneau(g, 4.6, 7.0, 3.0, 4.6, 1.2, 2.8, "e")
			_anneau(g, 9.4, 7.0, 3.0, 4.6, 1.2, 2.8, "e")
		"maison":
			_disque(g, 7.0, 7.0, 5.6, "e")
			_disque(g, 7.0, 7.0, 4.0, "d")
			_rect(g, 6, 4, 2, 6, "e")
			_rect(g, 5, 5, 4, 1, "e")
			_rect(g, 5, 8, 4, 1, "e")
			_p(g, 4, 4, "f")
		"plombier":
			_ligne(g, 3, 11, 9, 5, "f")
			_ligne(g, 4, 11, 10, 5, "f")
			_disque(g, 10.0, 4.0, 3.0, "f")
			_rect(g, 10, 1, 2, 3, ".")
			_disque(g, 3.0, 11.0, 1.4, "h")
		"rythme":
			_rect(g, 2, 2, 7, 10, "h")
			_rect(g, 5, 2, 7, 10, "f")
			_rect(g, 7, 6, 3, 2, "c")
			_p(g, 8, 5, "c")
			_p(g, 8, 8, "c")
			_p(g, 6, 3, "a")
		"coup_barre":
			_ligne(g, 7, 1, 7, 12, "f")
			_ligne(g, 1, 7, 12, 7, "f")
			_ligne(g, 2, 2, 11, 11, "f")
			_ligne(g, 11, 2, 2, 11, "f")
			_disque(g, 7.0, 7.0, 1.6, "g")
		"stagiaire":
			_disque(g, 7.0, 4.0, 2.6, "f")
			_rect(g, 3, 8, 8, 5, "g")
			_rect(g, 5, 8, 4, 1, "f")
			_p(g, 6, 3, "a")
			_p(g, 8, 3, "a")
		"fer_cheval":
			_anneau(g, 7.0, 6.5, 5.6, 5.6, 3.0, 3.0, "h")
			_rect(g, 5, 9, 4, 5, ".")
			_p(g, 2, 6, "f")
			_p(g, 11, 6, "f")
			_p(g, 3, 3, "f")
			_p(g, 10, 3, "f")
		"ventilo":
			_rect(g, 6, 1, 2, 5, "g")
			_rect(g, 6, 8, 2, 5, "g")
			_rect(g, 1, 6, 5, 2, "g")
			_rect(g, 8, 6, 5, 2, "g")
			_disque(g, 7.0, 7.0, 1.8, "f")
		"tirelire":
			_ellipse(g, 7.0, 8.0, 5.6, 4.0, "c")
			_rect(g, 4, 11, 2, 2, "c")
			_rect(g, 9, 11, 2, 2, "c")
			_rect(g, 6, 5, 3, 1, "a")
			_rect(g, 6, 1, 3, 3, "e")
			_p(g, 10, 7, "a")
			_p(g, 11, 4, "c")
		"pari":
			_rect(g, 2, 2, 10, 10, "f")
			for pip: Vector2i in [Vector2i(4, 4), Vector2i(9, 4), Vector2i(6, 7), Vector2i(4, 9), Vector2i(9, 9)]:
				_rect(g, pip.x, pip.y, 2, 1, "a")
				_rect(g, pip.x, pip.y + 1, 2, 1, "a")
		"bouclier":
			_rect(g, 3, 2, 8, 6, "d")
			_rect(g, 4, 8, 6, 2, "d")
			_rect(g, 5, 10, 4, 2, "d")
			_rect(g, 6, 12, 2, 1, "d")
			_rect(g, 6, 3, 2, 8, "e")
		"usurier":
			_disque(g, 7.0, 7.0, 5.6, "e")
			_disque(g, 7.0, 7.0, 4.2, "d")
			_rect(g, 6, 3, 2, 8, "a")
			_rect(g, 5, 4, 4, 1, "a")
			_rect(g, 5, 6, 4, 1, "a")
			_rect(g, 5, 9, 4, 1, "a")
		"chrono":
			_disque(g, 7.0, 7.5, 5.6, "f")
			_disque(g, 7.0, 7.5, 4.4, "b")
			_rect(g, 7, 4, 1, 4, "e")
			_rect(g, 7, 7, 3, 1, "e")
			_rect(g, 6, 0, 3, 1, "h")
		"combo":
			_ligne(g, 7, 1, 7, 12, "e")
			_ligne(g, 1, 7, 12, 7, "e")
			_ligne(g, 2, 2, 11, 11, "e")
			_ligne(g, 11, 2, 2, 11, "e")
			_disque(g, 7.0, 7.0, 2.6, "c")
			_p(g, 7, 7, "f")
		"turbo":
			_ligne(g, 8, 1, 4, 7, "e")
			_ligne(g, 9, 1, 5, 7, "e")
			_rect(g, 4, 7, 6, 1, "e")
			_ligne(g, 9, 7, 5, 13, "e")
			_ligne(g, 10, 7, 6, 13, "e")
		"gilet":
			_disque(g, 4.5, 5.0, 3.0, "c")
			_disque(g, 9.5, 5.0, 3.0, "c")
			for yy in range(5, 12):
				_rect(g, 2 + (yy - 5), yy, 10 - 2 * (yy - 5), 1, "c")
			_p(g, 3, 3, "f")
		"givre":
			_ligne(g, 7, 1, 7, 12, "f")
			_ligne(g, 1, 7, 12, 7, "f")
			_ligne(g, 2, 2, 11, 11, "h")
			_ligne(g, 11, 2, 2, 11, "h")
			_disque(g, 7.0, 7.0, 1.6, "f")
		"trefle":
			for c4: Vector2 in [Vector2(5.0, 5.0), Vector2(9.0, 5.0), Vector2(5.0, 9.0), Vector2(9.0, 9.0)]:
				_disque(g, c4.x, c4.y, 2.6, "g")
			_ligne(g, 8, 9, 10, 13, "g")
		"equipe":
			_disque(g, 4.5, 4.0, 2.2, "f")
			_disque(g, 9.5, 4.0, 2.2, "f")
			_rect(g, 2, 7, 5, 6, "g")
			_rect(g, 7, 7, 5, 6, "d")
	_contour(g)
	return _vers_map(g)

## Miniature de machine pour l'ecran MACHINES, 12x12 (recolorable via swap sur 'c').
static func map_mini_machine() -> PackedStringArray:
	var g: Array = _grille(14, 14)
	_rect(g, 2, 2, 10, 10, "c")
	_rect(g, 3, 3, 8, 2, "b")
	_rect(g, 3, 6, 8, 3, "a")
	_p(g, 4, 7, "e")
	_p(g, 7, 7, "f")
	_p(g, 10, 7, "e")
	_rect(g, 5, 10, 4, 1, "a")
	_contour(g)
	return _vers_map(g)

## Titre « SURCHAUFFE » compose avec la police 5x7 : face doree/orange, ombre rouge, contour noir.
static func map_titre(texte: String) -> PackedStringArray:
	var n: int = texte.length()
	var w: int = n * 6 + 4
	var h: int = 7 + 5
	var g: Array = _grille(w, h)
	for i in n:
		var lettre: String = texte[i]
		if not FONTE.has(lettre):
			continue
		var rangs: Array = FONTE[lettre]
		for y in 7:
			var rang: String = rangs[y]
			for x in 5:
				if rang[x] == "#":
					var px: int = 2 + i * 6 + x
					_p(g, px + 1, 2 + y + 1, "c")
	for i in n:
		var lettre: String = texte[i]
		if not FONTE.has(lettre):
			continue
		var rangs: Array = FONTE[lettre]
		for y in 7:
			var rang: String = rangs[y]
			for x in 5:
				if rang[x] == "#":
					var px: int = 2 + i * 6 + x
					_p(g, px, 2 + y, "e" if y < 4 else "d")
	_contour(g)
	return _vers_map(g)

# ---------------------------------------------------------------------------
# Textures en cache
# ---------------------------------------------------------------------------

## Texture par cle (cache). Cles : sym_<id>, ic_<carte>, coeur_plein, coeur_vide,
## levier_haut, levier_bas, carcasse, ampoule_on, ampoule_off, btn_normal, btn_press,
## btn_off, panel, panel_or, titre, mach_0..mach_5, mach_lock.
static func tex(cle: String) -> Texture2D:
	if _cache.has(cle):
		return _cache[cle]
	# Surcharge optionnelle : res://assets/sprites/<cle>.png remplace le sprite genere en code
	# (voir ASSETS_GEMINI.md). Sans fichier, le pixel art code est utilise.
	var chemin: String = "res://assets/sprites/%s.png" % cle
	if ResourceLoader.exists(chemin):
		var ext: Variant = load(chemin)
		if ext is Texture2D:
			_cache[cle] = ext
			return ext
	var t: ImageTexture = ImageTexture.create_from_image(image_de(cle))
	_cache[cle] = t
	return t

## Image brute correspondant a une cle (utile aussi pour les apercus).
static func image_de(cle: String) -> Image:
	if cle.begins_with("sym_"):
		return image(map_symbole(cle.substr(4)), 4)
	if cle.begins_with("ic_"):
		return image(map_icone(cle.substr(3)), 6)
	if cle.begins_with("mach_") and cle != "mach_lock":
		var couleurs: Array[String] = ["c", "d", "g", "e", "f", "h"]
		var idx: int = cle.substr(5).to_int() % couleurs.size()
		return image(map_mini_machine(), 4, {"c": couleurs[idx]})
	if cle.begins_with("btn_") and cle.ends_with("_n") or cle.begins_with("btn_") and cle.ends_with("_p"):
		var morceaux: PackedStringArray = cle.split("_")
		return img_bouton(morceaux[1], morceaux[2] == "p")
	match cle:
		"mach_lock":
			return image(map_mini_machine(), 4, {"c": "h", "e": "b", "f": "b"})
		"coeur_plein":
			return image(map_coeur(true), 2)
		"coeur_vide":
			return image(map_coeur(false), 2)
		"levier_haut":
			return image(map_levier(false), 4)
		"levier_bas":
			return image(map_levier(true), 4)
		"carcasse":
			return image(map_carcasse(), 4)
		"ampoule_on":
			return image(map_ampoule(), 2)
		"ampoule_off":
			return image(map_ampoule(), 2, {"e": "d", "f": "d"})
		"btn_normal":
			return img_bouton("orange", false)
		"btn_press":
			return img_bouton("orange", true)
		"btn_off":
			return img_bouton("off", false)
		"panel":
			return img_panneau(Pal.PRUNE, Pal.GRIS)
		"panel_or":
			return img_panneau(Pal.PRUNE, Pal.DORE)
		"panel_clair":
			return img_panneau(Pal.CREME, Pal.GRIS)
		"panel_nuit":
			return img_panneau(Pal.ENCRE, Pal.PRUNE)
		"panel_rouge":
			return img_panneau(Pal.ROUGE, Pal.ORANGE)
		"panel_vert":
			return img_panneau(Pal.VERT, Pal.CREME)
		"titre":
			return image(map_titre("SURCHAUFFE"), 6)
	push_warning("Pixels : cle de sprite inconnue « %s »" % cle)
	return image(PackedStringArray(["a"]), 2)

## Prechauffe le cache (appele au Boot pour eviter tout a-coup en jeu).
static func precharger() -> void:
	var cles: Array[String] = ["coeur_plein", "coeur_vide", "levier_haut", "levier_bas", "carcasse",
		"ampoule_on", "ampoule_off", "btn_normal", "btn_press", "btn_off", "panel", "panel_or", "titre", "mach_lock"]
	for s: String in SYMBOLES:
		cles.append("sym_" + s)
	for c: String in CARTES_ICONES:
		cles.append("ic_" + c)
	for i in 12:
		cles.append("mach_%d" % i)
	for cle: String in cles:
		tex(cle)

# ---------------------------------------------------------------------------
# Aides d'interface (police par defaut : 8 / 16 / 32, contour noir de 4)
# ---------------------------------------------------------------------------

# Schemas de boutons : [corps, reflet, levre, couleur du texte]
const SCHEMAS: Dictionary = {
	"orange": [Pal.ORANGE, Pal.DORE, Pal.ROUGE, Pal.ENCRE],
	"vert": [Pal.VERT, Pal.CREME, Pal.GRIS, Pal.ENCRE],
	"rouge": [Pal.ROUGE, Pal.ORANGE, Pal.PRUNE, Pal.CREME],
	"or": [Pal.DORE, Pal.CREME, Pal.ORANGE, Pal.ENCRE],
	"prune": [Pal.PRUNE, Pal.GRIS, Pal.ENCRE, Pal.CREME],
	"off": [Pal.PRUNE, Pal.GRIS, Pal.ENCRE, Pal.GRIS],
}

static func _bloc(img: Image, x: int, y: int, col: Color) -> void:
	# un « pixel » de carte = 2x2 pixels ecran
	if x < 0 or y < 0 or x >= 16 or y >= 16:
		return
	for dx in 2:
		for dy in 2:
			img.set_pixel(x * 2 + dx, y * 2 + dy, col)

## Bouton 3D 16x16 (x2) a 9-slice : contour encre, reflet en haut, levre sombre en bas.
## Etat « enfonce » : le bouton descend de 2 pixels de carte et la levre se resserre.
static func img_bouton(schema: String, enfonce: bool) -> Image:
	var sc: Array = SCHEMAS.get(schema, SCHEMAS["orange"])
	var corps: Color = sc[0]
	var reflet: Color = sc[1]
	var levre: Color = sc[2]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var haut: int = 2 if enfonce else 0
	var bas_levre: int = 14 if enfonce else 13   # premiere ligne de levre
	var nlev: int = 1 if enfonce else 2
	for y in range(haut, 16):
		for x in 16:
			var col: Color = corps
			if y == haut or y == 15 or x == 0 or x == 15:
				col = Pal.ENCRE
			elif y == haut + 1 and not enfonce:
				col = reflet
			elif y >= bas_levre and y < bas_levre + nlev:
				col = levre
			_bloc(img, x, y, col)
	# coins coupes
	for p: Vector2i in [Vector2i(0, haut), Vector2i(15, haut), Vector2i(0, 15), Vector2i(15, 15)]:
		_bloc(img, p.x, p.y, Color(0, 0, 0, 0))
	return img

## Panneau 16x16 (x2) : contour encre, liseré colore, corps uni, bord bas assombri.
static func img_panneau(corps: Color, bord: Color) -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			var col: Color = corps
			if y == 0 or y == 15 or x == 0 or x == 15:
				col = Pal.ENCRE
			elif y == 1 or y == 14 or x == 1 or x == 14:
				col = bord
			_bloc(img, x, y, col)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15)]:
		_bloc(img, p.x, p.y, Color(0, 0, 0, 0))
	return img

static func style(cle: String) -> StyleBoxTexture:
	if _styles.has(cle):
		return _styles[cle]
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = tex(cle)
	sb.texture_margin_left = 8.0
	sb.texture_margin_right = 8.0
	sb.texture_margin_top = 8.0
	sb.texture_margin_bottom = 8.0
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	if cle.begins_with("btn_") and cle.ends_with("_p") or cle == "btn_press":
		sb.content_margin_top = 10.0     # le texte descend avec le bouton
		sb.content_margin_bottom = 6.0
	elif cle.begins_with("btn_"):
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 10.0
	else:
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 10.0
	_styles[cle] = sb
	return sb

## Police pixel + ombre portee dure d'un pixel de police (taille/8) : remplace le contour noir,
## inutilisable sur une police bitmap.
static func appliquer_police(c: Control, taille: int, couleur: Color, ombre: bool = true) -> void:
	c.add_theme_font_override("font", PixelFont.police())
	c.add_theme_font_size_override("font_size", taille)
	c.add_theme_color_override("font_color", couleur)
	c.add_theme_constant_override("outline_size", 0)
	if ombre:
		c.add_theme_color_override("font_shadow_color", Pal.ENCRE)
		c.add_theme_constant_override("shadow_offset_x", maxi(1, taille / 8))
		c.add_theme_constant_override("shadow_offset_y", maxi(1, taille / 8))
	c.add_theme_constant_override("line_spacing", maxi(1, taille / 8))

static func label(texte: String, taille: int = 16, couleur: Color = Pal.CREME, ombre: bool = true) -> Label:
	var l: Label = Label.new()
	l.text = texte
	appliquer_police(l, taille, couleur, ombre)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func bouton(texte: String, taille: int = 16, w: float = 0.0, h: float = 0.0, schema: String = "orange") -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", PixelFont.police())
	b.add_theme_font_size_override("font_size", taille)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_constant_override("line_spacing", maxi(1, taille / 8))
	habiller(b, schema)
	if w > 0.0 or h > 0.0:
		b.custom_minimum_size = Vector2(w, h)
		b.size = Vector2(w, h)
	rebond(b)
	return b

## (Re)colore un bouton : orange / vert / rouge / or / prune. Le texte est sombre sur les
## fonds clairs, clair (avec ombre) sur les fonds sombres. Etat desactive : toujours « off ».
static func habiller(b: Button, schema: String) -> void:
	var sc: Array = SCHEMAS.get(schema, SCHEMAS["orange"])
	b.add_theme_stylebox_override("normal", style("btn_%s_n" % schema))
	b.add_theme_stylebox_override("hover", style("btn_%s_n" % schema))
	b.add_theme_stylebox_override("pressed", style("btn_%s_p" % schema))
	b.add_theme_stylebox_override("disabled", style("btn_off_n"))
	var texte: Color = sc[3]
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(nom, texte)
	b.add_theme_color_override("font_disabled_color", Pal.GRIS)
	var clair: bool = texte == Pal.CREME
	b.add_theme_color_override("font_shadow_color", Pal.ENCRE if clair else Color(Pal.CREME, 0.0))
	var o: int = maxi(1, b.get_theme_font_size("font_size") / 8)
	b.add_theme_constant_override("shadow_offset_x", o)
	b.add_theme_constant_override("shadow_offset_y", o)

## Petit « squash » au toucher (rebond elastique au relachement).
static func rebond(b: Button) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.96, 0.94), 0.05))
	b.button_up.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## TextureRect net (nearest, ignore la souris) a la taille native de la texture.
static func rect(t: Texture2D, pos: Vector2 = Vector2.ZERO) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = t.get_size()
	r.position = pos
	return r

## Panneau 9-slice (fond de carte, fenetre) avec ombre portee dure (decalee de 6 px).
static func panneau(w: float, h: float, cle: String = "panel", ombre: bool = true) -> Panel:
	var p: Panel = Panel.new()
	p.add_theme_stylebox_override("panel", style(cle))
	p.size = Vector2(w, h)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ombre:
		var o: ColorRect = ColorRect.new()
		o.color = Color(Pal.ENCRE, 0.6)
		o.position = Vector2(4, 8)
		o.size = Vector2(w - 8.0, h - 4.0)
		o.show_behind_parent = true
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(o)
	return p
