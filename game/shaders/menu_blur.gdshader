shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 col = textureLod(screen_tex, SCREEN_UV, 2.4).rgb;
	COLOR = vec4(col * 0.58, 0.8);
}
