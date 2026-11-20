extends SubViewportContainer
## Fond animé en tourbillon façon Balatro, limité aux couleurs de la palette (encre / prune /
## une couleur d'accent). Rendu dans un SubViewport 1/3 de résolution : gros pixels nets et
## coût GPU minime. Les nuances sont obtenues par tramage (dithering), jamais par dégradé.

const Pal = preload("res://art/Palette.gd")

const SHADER: String = """
shader_type canvas_item;
uniform vec4 c0 : source_color = vec4(0.078, 0.059, 0.106, 1.0);
uniform vec4 c1 : source_color = vec4(0.169, 0.106, 0.239, 1.0);
uniform vec4 c2 : source_color = vec4(0.91, 0.27, 0.235, 1.0);
uniform float vitesse = 1.0;
uniform float accent = 0.55;      // part visible de la couleur d'accent (0..1)
uniform float echelle = 0.026;    // taille des motifs : plus petit = plus de couleur claire

float tram(vec2 p, float k) {
	vec2 q = mod(floor(p) + vec2(k * 3.0, k * 5.0), 4.0);
	float i = q.x + q.y * 4.0;
	// matrice de Bayer 4x4
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[int(i)] / 16.0;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	vec2 uv = (fc - 0.5 * res) / length(res);
	float uv_len = length(uv);
	float t = TIME * vitesse;
	float ang = atan(uv.y, uv.x) + t * -0.4 + 302.2 - 20.0 * (0.25 * uv_len + 0.75);
	vec2 mid = (res / length(res)) / 2.0;
	uv = vec2(uv_len * cos(ang) + mid.x, uv_len * sin(ang) + mid.y) - mid;
	uv *= 30.0;
	float sp = t * 2.0;
	vec2 uv2 = vec2(uv.x + uv.y);
	for (int i = 0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + sp * 0.131121), sin(uv2.x - 0.113 * sp));
		uv -= cos(uv.x + uv.y) - sin(uv.x * 0.711 - uv.y);
	}
	float cm = 0.25 * 2.0 + 0.5 * 0.25 + 1.2;
	float paint = min(2.0, max(0.0, length(uv) * echelle * cm));
	float w1 = max(0.0, 1.0 - cm * 0.55 * abs(1.0 - paint)) * 1.15;  // c1 (prune), bande large
	float w2 = max(0.0, 1.0 - cm * abs(paint)) * accent;     // c2 (accent)
	float w0 = 1.0 - min(1.0, w1 + w2);                       // c0 (encre)
	// choix de la couleur dominante, departagee par le tramage
	w0 += tram(fc, 0.0) * 0.30;
	w1 += tram(fc, 1.0) * 0.30;
	w2 += tram(fc, 2.0) * 0.30;
	vec4 col = c0;
	float best = w0;
	if (w1 > best) { best = w1; col = c1; }
	if (w2 > best) { col = c2; }
	COLOR = vec4(col.rgb, 1.0);
}
"""

var _mat: ShaderMaterial = null

func _init() -> void:
	stretch = true
	stretch_shrink = 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp: SubViewport = SubViewport.new()
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var r: ColorRect = ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	r.material = _mat
	vp.add_child(r)

## accent : couleur d'accent de la palette ; part : visibilité de l'accent (0..1) ; vitesse du tourbillon.
func regler(accent: Color, part: float = 0.55, vitesse: float = 1.0) -> void:
	_mat.set_shader_parameter("c2", accent)
	_mat.set_shader_parameter("accent", part)
	_mat.set_shader_parameter("vitesse", vitesse)

func regler_vitesse(v: float) -> void:
	_mat.set_shader_parameter("vitesse", v)

## Fabrique pratique : ajoute un fond derrière tout le reste du parent.
static func ajouter(parent: Control, accent: Color = Pal.ROUGE, part: float = 0.55, vitesse: float = 1.0) -> Control:
	var f: Control = (load("res://ui/Fond.gd") as GDScript).new()
	parent.add_child(f)
	parent.move_child(f, 0)
	f.regler(accent, part, vitesse)
	return f
