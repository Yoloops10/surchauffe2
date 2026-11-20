extends SceneTree
## Outil de dev : assemble tous les sprites dans une planche PNG pour controle visuel.
## Usage : godot --headless --path . --script res://tools/preview_sprites.gd -- /chemin/sortie.png

const Pixels = preload("res://art/Pixels.gd")
const Pal = preload("res://art/Palette.gd")

func _initialize() -> void:
	var sortie: String = "/tmp/planche.png"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		sortie = args[0]
	var cles: Array[String] = []
	for s: String in Pixels.SYMBOLES:
		cles.append("sym_" + s)
	cles.append_array(["coeur_plein", "coeur_vide", "levier_haut", "levier_bas", "ampoule_on", "ampoule_off"])
	for c: String in Pixels.CARTES_ICONES:
		cles.append("ic_" + c)
	for i in 6:
		cles.append("mach_%d" % i)
	cles.append("mach_lock")
	var planche: Image = Image.create(900, 1000, false, Image.FORMAT_RGBA8)
	planche.fill(Pal.PRUNE)
	var x: int = 8
	var y: int = 8
	var ligne_h: int = 0
	for cle: String in cles:
		var img: Image = Pixels.image_de(cle)
		if x + img.get_width() > 890:
			x = 8
			y += ligne_h + 8
			ligne_h = 0
		planche.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))
		x += img.get_width() + 8
		ligne_h = maxi(ligne_h, img.get_height())
	y += ligne_h + 8
	# carcasse, bouton, titre
	for cle: String in ["carcasse", "titre", "btn_normal", "btn_press", "btn_off"]:
		var img2: Image = Pixels.image_de(cle)
		if x + img2.get_width() > 890 or cle == "carcasse" or cle == "titre":
			x = 8
			y += ligne_h + 8
			ligne_h = 0
		planche.blit_rect(img2, Rect2i(0, 0, img2.get_width(), img2.get_height()), Vector2i(x, y))
		x += img2.get_width() + 8
		ligne_h = maxi(ligne_h, img2.get_height())
	planche.save_png(sortie)
	print("Planche ecrite : ", sortie)
	quit()
