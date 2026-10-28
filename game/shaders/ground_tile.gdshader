shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float use_tex = 0.0;
uniform float contrast = 1.0;
uniform vec3 tone_mid : source_color = vec3(0.32, 0.24, 0.15);

void fragment() {
	vec3 tex = mix(vec3(1.0), texture(albedo_tex, UV).rgb, clamp(use_tex, 0.0, 1.0));
	tex = mix(tone_mid, tex, clamp(contrast, 0.0, 1.0));
	ALBEDO = tex * COLOR.rgb;
	ROUGHNESS = 0.94;
}
