shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 ice_color : source_color = vec4(0.62, 0.86, 1.0, 0.72);

void fragment() {
	ALBEDO = ice_color.rgb;
	ALPHA = ice_color.a;
	ROUGHNESS = 0.12;
	EMISSION = ice_color.rgb * 0.25;
}
