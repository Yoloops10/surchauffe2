extends Node
## Sons generes en code (AudioStreamWAV rempli par un buffer) : aucun fichier audio.
## Sons : tap, spin, jackpot, surchauffe, table. Le mute est persistant (Save.mute).

const RATE: int = 22050
const POLYPHONIE: int = 6

var _sons: Dictionary = {}
var _joueurs: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in POLYPHONIE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_joueurs.append(p)
	_sons["tap"] = _flux(_gen_tap())
	_sons["spin"] = _flux(_gen_spin(0.6, 0.03, 0.05))          # arcade
	_sons["spin_lent"] = _flux(_gen_spin(1.2, 0.045, 0.09))     # classique
	_sons["jackpot"] = _flux(_gen_jackpot())
	_sons["surchauffe"] = _flux(_gen_surchauffe())
	_sons["table"] = _flux(_gen_table())
	# Surcharge optionnelle : res://assets/audio/sfx_<nom>.ogg|.wav|.mp3 (voir ASSETS_GEMINI.md)
	for nom: String in _sons.keys():
		var ext: AudioStream = _charger_audio("sfx_" + nom)
		if ext != null:
			_sons[nom] = ext
	_musique_joueur = AudioStreamPlayer.new()
	_musique_joueur.volume_db = -12.0
	add_child(_musique_joueur)

var _musique_joueur: AudioStreamPlayer = null
var _musique_nom: String = ""

func _charger_audio(base: String) -> AudioStream:
	for ext: String in ["ogg", "mp3", "wav"]:
		var chemin: String = "res://assets/audio/%s.%s" % [base, ext]
		if ResourceLoader.exists(chemin):
			var s: Variant = load(chemin)
			if s is AudioStream:
				return s
	return null

## Musique de fond en boucle (menu, run, gameover). Sans fichier fourni : silence.
var _derniere_run: String = ""
func musique(nom: String) -> void:
	if nom == _musique_nom:
		return
	_musique_nom = nom
	var fichier: String = nom
	if nom == "run":   # plusieurs pistes de run (run, run2, run3...) : tirage au sort, sans repeter la derniere
		var dispo: Array[String] = []
		for k: String in ["run", "run2", "run3", "run4", "run5"]:
			if k != _derniere_run and _charger_audio("musique_" + k) != null:
				dispo.append(k)
		if not dispo.is_empty():
			fichier = dispo.pick_random()
		_derniere_run = fichier
	var s: AudioStream = _charger_audio("musique_" + fichier)
	if s == null:
		_musique_joueur.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_musique_joueur.stream = s
	_musique_joueur.play()

func _process(_delta: float) -> void:
	if _musique_joueur != null:
		_musique_joueur.stream_paused = Save.mute

## pitch : hauteur du son (1,0 = normal). Le tap monte en gamme avec la chauffe.
func jouer(nom: String, pitch: float = 1.0) -> void:
	if Save.mute or not _sons.has(nom):
		return
	for p: AudioStreamPlayer in _joueurs:
		if not p.playing:
			p.stream = _sons[nom]
			p.pitch_scale = pitch
			p.play()
			return
	# tous occupes : on coupe le premier
	_joueurs[0].stream = _sons[nom]
	_joueurs[0].pitch_scale = pitch
	_joueurs[0].play()

# ---------------------------------------------------------------------------
# Generation des formes d'onde
# ---------------------------------------------------------------------------

func _flux(echantillons: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(echantillons.size() * 2)
	for i in echantillons.size():
		var v: int = int(clampf(echantillons[i], -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, v)
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

static func _carre(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

static func _triangle(phase: float) -> float:
	return absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0

## Tap : petit « tic » carre descendant.
func _gen_tap() -> PackedFloat32Array:
	var n: int = int(RATE * 0.07)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		var f: float = 700.0 - 5000.0 * t
		phase += f / float(RATE)
		var env: float = pow(1.0 - float(i) / float(n), 2.0)
		out[i] = _carre(phase) * env * 0.45
	return out

## Spin : cliquetis de plus en plus espaces pendant 1,2 s.
func _gen_spin(duree: float, pas0: float, pas1: float) -> PackedFloat32Array:
	var n: int = int(RATE * duree)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var prochain: float = 0.0
	var debut: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t: float = float(i) / float(RATE)
		if t >= prochain:
			debut = t
			prochain += pas0 + pas1 * (t / duree)
		var dt: float = t - debut
		var env: float = exp(-dt * 70.0)
		var bruit: float = rng.randf_range(-1.0, 1.0)
		out[i] = (bruit * 0.5 + sin(TAU * 1100.0 * t) * 0.3) * env * 0.5
	return out

## Suite de notes carrees/triangle (arpege).
func _notes(freqs: Array[float], duree_note: float, queue: float, vol: float) -> PackedFloat32Array:
	var n_note: int = int(RATE * duree_note)
	var n_queue: int = int(RATE * queue)
	var total: int = n_note * freqs.size() + n_queue
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	for k in freqs.size():
		var phase: float = 0.0
		for i in n_note + (n_queue if k == freqs.size() - 1 else 0):
			var idx: int = k * n_note + i
			if idx >= total:
				break
			phase += freqs[k] / float(RATE)
			var tt: float = float(i) / float(n_note)
			var env: float = exp(-tt * 1.8) if i < n_note else exp(-1.8 - float(i - n_note) / float(RATE) * 6.0)
			out[idx] = (_carre(phase) * 0.35 + _triangle(phase) * 0.45) * env * vol
	return out

func _gen_jackpot() -> PackedFloat32Array:
	var f: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0]
	return _notes(f, 0.09, 0.35, 0.8)

func _gen_table() -> PackedFloat32Array:
	var f: Array[float] = [523.25, 659.25, 783.99]
	return _notes(f, 0.12, 0.25, 0.8)

## Surchauffe : grondement grave (dent de scie + bruit), hauteur qui s'effondre.
func _gen_surchauffe() -> PackedFloat32Array:
	var n: int = int(RATE * 0.7)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t: float = float(i) / float(RATE)
		var f: float = 110.0 - 70.0 * (t / 0.7)
		phase += f / float(RATE)
		var scie: float = fmod(phase, 1.0) * 2.0 - 1.0
		var env: float = pow(1.0 - float(i) / float(n), 1.5)
		out[i] = (scie * 0.6 + rng.randf_range(-1.0, 1.0) * 0.35) * env * 0.8
	return out
