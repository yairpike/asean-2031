shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.45, 0.25, 0.9);

void fragment() {
	float across = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float core = smoothstep(0.5, 0.0, abs(UV.x - 0.5));
	float pulse = 0.55 + 0.45 * sin(UV.y * 28.0 - TIME * 9.0);
	float glow = across * pulse * (0.45 + 0.55 * core);
	ALBEDO = beam_color.rgb;
	ALPHA = beam_color.a * glow;
	EMISSION = beam_color.rgb * (1.4 + core);
}
