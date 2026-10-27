shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

void vertex() {
	float amp = mix(0.07, 0.035, COLOR.r);
	VERTEX.y += sin(VERTEX.x * 0.42 + TIME * 1.25) * cos(VERTEX.z * 0.31 + TIME * 0.85) * amp;
}

void fragment() {
	vec3 shallow_col = vec3(0.24, 0.58, 0.6);
	vec3 deep_col = vec3(0.03, 0.09, 0.18);
	ALBEDO = mix(shallow_col, deep_col, COLOR.r);
	ROUGHNESS = 0.16;
	METALLIC = 0.04;
	ALPHA = mix(0.8, 0.95, COLOR.r);
}
