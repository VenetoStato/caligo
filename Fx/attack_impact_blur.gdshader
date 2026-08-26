shader_type canvas_item;
render_mode blend_mix;

// Sfoca esclusivamente la texture delle particelle del colpo, non il mondo.
uniform vec2 motion_direction = vec2(1.0, 0.0);
uniform float smear_texels : hint_range(0.0, 96.0) = 46.0;

void fragment() {
	vec2 direction = normalize(motion_direction + vec2(0.0001, 0.0001));
	vec2 step_uv = direction * TEXTURE_PIXEL_SIZE * smear_texels;
	// Scia vera lungo la traiettoria del colpo: più lunga dietro, non alone
	// uniforme attorno al frammento.
	vec4 color = texture(TEXTURE, UV) * 0.36;
	color += texture(TEXTURE, UV - step_uv * 0.25) * 0.21;
	color += texture(TEXTURE, UV - step_uv * 0.52) * 0.17;
	color += texture(TEXTURE, UV - step_uv * 0.82) * 0.13;
	color += texture(TEXTURE, UV + step_uv * 0.18) * 0.08;
	color += texture(TEXTURE, UV + step_uv * 0.42) * 0.05;
	COLOR = color;
}
