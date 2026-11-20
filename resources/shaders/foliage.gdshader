shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Folhagem low-poly com cor por instância (MultiMesh) e balanço de vento.
// O balanço cresce com a altura local do vértice: a base fica parada.

uniform float sway_strength = 0.06;
uniform float sway_speed = 1.6;
uniform float base_height = 0.0;
uniform float sway_height = 1.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = clamp((VERTEX.y - base_height) / max(sway_height, 0.001), 0.0, 1.0);
	float phase = TIME * sway_speed + wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(phase) * sway_strength * w;
	VERTEX.z += cos(phase * 0.8) * sway_strength * 0.6 * w;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
