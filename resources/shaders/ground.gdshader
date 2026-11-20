shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Chão da floresta: manchas de grama em dois tons e áreas secas, em coordenadas de mundo.

uniform vec3 color_a : source_color = vec3(0.33, 0.53, 0.25);
uniform vec3 color_b : source_color = vec3(0.44, 0.63, 0.29);
uniform vec3 color_dry : source_color = vec3(0.60, 0.60, 0.35);
uniform vec3 color_dirt : source_color = vec3(0.45, 0.37, 0.25);

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
	float n = vnoise(p * 0.06) * 0.6 + vnoise(p * 0.21) * 0.4;
	vec3 c = mix(color_a, color_b, n);
	float dry = vnoise(p * 0.013 + 17.0);
	c = mix(c, color_dry, smoothstep(0.58, 0.82, dry) * 0.75);
	float dirt = vnoise(p * 0.035 + 41.0);
	c = mix(c, color_dirt, smoothstep(0.78, 0.92, dirt) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
