shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 ice_color : source_color = vec4(0.72, 0.9, 1.0, 0.82);

void fragment() {
	ALBEDO = ice_color.rgb;
	ALPHA = ice_color.a;
	ROUGHNESS = 0.12;
	EMISSION = ice_color.rgb * 0.25;
}
