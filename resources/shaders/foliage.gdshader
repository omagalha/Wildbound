shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Folhagem low-poly com cor por instância (MultiMesh), vento e sombreamento falso:
// a base de cada peça (copa, camada do pinheiro, tufo de grama) fica mais escura,
// a ponta mais clara, e a cor varia um pouco pelo mundo. Barato e dá volume.

uniform float sway_strength = 0.06;
uniform float sway_speed = 1.6;
uniform float base_height = 0.0;
uniform float sway_height = 1.0;
// Quanto a base escurece (0 = nada) e quanto a ponta clareia.
uniform float base_darkness = 0.45;
uniform float tip_lightness = 0.18;
// Brilho de contraluz nas bordas (folhas finas contra o sol).
uniform float rim_strength = 0.18;
// Quanto a normal é puxada para cima: folhas finas e grama recebem luz como
// uma superfície virada para o céu, sem lados escuros/azulados (1 = grama).
uniform float normal_up_blend = 0.35;

varying float height_ratio;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = wp;
	float w = clamp((VERTEX.y - base_height) / max(sway_height, 0.001), 0.0, 1.0);
	height_ratio = w;
	float phase = TIME * sway_speed + wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(phase) * sway_strength * w;
	VERTEX.z += cos(phase * 0.8) * sway_strength * 0.6 * w;
}

void fragment() {
	// A cor da instância vem em sRGB; ALBEDO espera linear.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// variação suave por região (manchas de tom no mundo)
	float n = hash(floor(world_pos.xz * 0.15));
	base *= mix(0.92, 1.08, n);
	float g = smoothstep(0.0, 1.0, height_ratio);
	vec3 col = mix(base * (1.0 - base_darkness), base * (1.0 + tip_lightness), g);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	vec3 n_face = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(n_face, up_view, normal_up_blend));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * rim * rim_strength * g;
}
