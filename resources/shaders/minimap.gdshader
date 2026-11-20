shader_type canvas_item;
// Recorta o mapa da ilha num círculo centrado no jogador, com borda escurecida.

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 center_uv = vec2(0.5);
uniform float radius_uv = 0.1;
uniform vec4 sea_color : source_color = vec4(0.06, 0.24, 0.36, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	if (r > 1.0) {
		discard;
	}
	vec2 uv = center_uv + d * 2.0 * radius_uv;
	vec4 c = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		c = sea_color;
	}
	c.rgb *= mix(1.0, 0.6, smoothstep(0.72, 1.0, r));
	COLOR = vec4(c.rgb, 0.97);
}
