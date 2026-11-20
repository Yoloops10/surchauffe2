extends CanvasLayer
## Effets globaux : overlay CRT (lignes de balayage + vignette) et fondu entre les écrans.
## Pas d'état de jeu ici.

const Pal = preload("res://art/Palette.gd")

const SHADER_CRT: String = """
shader_type canvas_item;
uniform vec2 taille = vec2(540.0, 960.0);
uniform float balayage = 0.07;
uniform float vignette = 0.5;
void fragment() {
	vec2 p = UV * taille;
	float l = mod(floor(p.y / 2.0), 2.0) * balayage;
	vec2 d = (UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.30, 0.80, length(d)) * vignette;
	COLOR = vec4(0.078, 0.059, 0.106, clamp(l + v, 0.0, 1.0));
}
"""

var _crt: ColorRect
var _fondu: ColorRect
var _en_cours: bool = false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crt = ColorRect.new()
	_crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER_CRT
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	_crt.material = m
	add_child(_crt)
	_fondu = ColorRect.new()
	_fondu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondu.color = Pal.ENCRE
	_fondu.modulate.a = 0.0
	_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondu)
	get_viewport().size_changed.connect(_maj_taille)
	_maj_taille()

func _maj_taille() -> void:
	var v: Vector2 = get_viewport().get_visible_rect().size
	(_crt.material as ShaderMaterial).set_shader_parameter("taille", v)

## Change d'écran avec un fondu à travers l'encre (bloque les appuis pendant la transition).
func aller(chemin: String) -> void:
	if _en_cours:
		return
	_en_cours = true
	_fondu.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.tween_property(_fondu, "modulate:a", 1.0, 0.16)
	await tw.finished
	get_tree().change_scene_to_file(chemin)
	await get_tree().process_frame
	var tw2: Tween = create_tween()
	tw2.tween_property(_fondu, "modulate:a", 0.0, 0.22)
	await tw2.finished
	_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_en_cours = false
