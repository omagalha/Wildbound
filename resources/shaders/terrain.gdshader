shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Terreno da ilha. A cor vem por vértice (região, altura, inclinação, areia);
// no centro (alfa do vértice = 1) usa o visual antigo do chão da floresta,
// com manchas de grama, musgo, terra e áreas secas. Uma textura fina em
// coordenadas de mundo dá detalhe em todas as regiões.

uniform float sea_level = -1.5;
uniform vec3 color_a : source_color = vec3(0.27, 0.47, 0.2);
uniform vec3 color_b : source_color = vec3(0.4, 0.6, 0.25);
uniform vec3 color_dry : source_color = vec3(0.6, 0.58, 0.32);
uniform vec3 color_dirt : source_color = vec3(0.42, 0.33, 0.22);
uniform vec3 color_moss : source_color = vec3(0.2, 0.38, 0.2);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Visual da floresta (igual ao chão antigo).
	float n = vnoise(p * 0.05) * 0.5 + vnoise(p * 0.17) * 0.3 + vnoise(p * 0.6) * 0.2;
	vec3 forest = mix(color_a, color_b, n);
	forest = mix(forest, color_moss, smoothstep(0.55, 0.8, vnoise(p * 0.03 + 5.0)) * 0.6);
	forest = mix(forest, color_dry, smoothstep(0.6, 0.85, vnoise(p * 0.013 + 17.0)) * 0.7);
	forest = mix(forest, color_dirt, smoothstep(0.8, 0.93, vnoise(p * 0.035 + 41.0)) * 0.65);
	// Cor da região (vértice, em sRGB -> linear), com manchas suaves.
	vec3 region = pow(COLOR.rgb, vec3(2.2));
	region *= mix(0.88, 1.1, vnoise(p * 0.08) * 0.6 + vnoise(p * 0.4) * 0.4);
	vec3 c = mix(region, forest, COLOR.a);
	c *= mix(0.94, 1.05, vnoise(p * 3.5));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
