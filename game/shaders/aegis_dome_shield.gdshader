shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shield_color : source_color = vec4(0.35, 0.75, 1.0, 0.38);

void fragment() {
	ALBEDO = shield_color.rgb;
	ALPHA = shield_color.a;
	ROUGHNESS = 0.05;
	EMISSION = shield_color.rgb * 0.45;
}
