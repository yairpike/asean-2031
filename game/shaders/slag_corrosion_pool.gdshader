shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 slag_color : source_color = vec4(0.72, 0.38, 0.08, 0.7);

void fragment() {
	ALBEDO = slag_color.rgb;
	ALPHA = slag_color.a;
	ROUGHNESS = 0.55;
	EMISSION = slag_color.rgb * 0.15;
}
