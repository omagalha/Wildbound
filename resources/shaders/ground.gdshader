shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Chão da floresta: manchas de grama em vários tons, musgo, áreas secas, terra e
// um pontilhado fino que dá textura de perto, tudo em coordenadas de mundo.

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
	float n = vnoise(p * 0.05) * 0.5 + vnoise(p * 0.17) * 0.3 + vnoise(p * 0.6) * 0.2;
	vec3 c = mix(color_a, color_b, n);
	c = mix(c, color_moss, smoothstep(0.55, 0.8, vnoise(p * 0.03 + 5.0)) * 0.6);
	float dry = vnoise(p * 0.013 + 17.0);
	c = mix(c, color_dry, smoothstep(0.6, 0.85, dry) * 0.7);
	float dirt = vnoise(p * 0.035 + 41.0);
	c = mix(c, color_dirt, smoothstep(0.8, 0.93, dirt) * 0.65);
	// pontilhado fino: folhinhas e sombras miúdas
	float speck = vnoise(p * 3.5);
	c *= mix(0.94, 1.05, speck);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
