shader_type spatial;
render_mode diffuse_lambert, cull_disabled, depth_draw_always;
// Mar estilizado: ondas suaves, azul profundo com cristas mais claras,
// brilho do sol (fresnel) e leve transparência perto da superfície.

uniform vec3 deep_color : source_color = vec3(0.05, 0.27, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.14, 0.55, 0.62);
uniform float wave_height = 0.25;
uniform float wave_speed = 0.8;
uniform float alpha = 0.82;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wp.x * 0.08 + TIME * wave_speed) * 0.6 + sin(wp.z * 0.11 + TIME * wave_speed * 1.3) * 0.4
		+ sin((wp.x + wp.z) * 0.23 + TIME * wave_speed * 1.9) * 0.25;
	VERTEX.y += w * wave_height;
	world_pos = wp;
	world_pos.y += w * wave_height;
}

void fragment() {
	float crest = smoothstep(0.1, 0.35, world_pos.y - (MODEL_MATRIX[3].y));
	float pattern = sin(world_pos.x * 0.6 + TIME) * sin(world_pos.z * 0.5 - TIME * 0.7);
	vec3 c = mix(deep_color, shallow_color, crest * 0.6 + pattern * 0.08 + 0.15);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = vec3(0.5, 0.7, 0.8) * fresnel * 0.25;
	ALPHA = clamp(alpha + fresnel * 0.15, 0.0, 1.0);
}
