shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

void vertex() {
	float drop = mod(TIME * 18.0 + VERTEX.x * 0.17 + VERTEX.z * 0.09, 16.0);
	VERTEX.y -= drop;
}

void fragment() {
	ALBEDO = vec3(0.78, 0.84, 0.9);
	ALPHA = 0.42;
}
