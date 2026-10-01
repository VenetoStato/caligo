shader_type canvas_item;
render_mode blend_mix;

// Sfocatura locale della sola texture del fondale. Non legge lo schermo e non
// attraversa il percorso driver che causava il crash Intel in Compatibility.
uniform float blur_radius : hint_range(0.0, 8.0) = 2.4;
uniform float edge_fade : hint_range(0.02, 0.35) = 0.16;
uniform vec4 atmosphere_tint : source_color = vec4(0.68, 0.82, 0.86, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.14;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 source = texture(TEXTURE, UV) * 0.28;
	source += texture(TEXTURE, UV + vec2(texel.x, 0.0)) * 0.12;
	source += texture(TEXTURE, UV - vec2(texel.x, 0.0)) * 0.12;
	source += texture(TEXTURE, UV + vec2(0.0, texel.y)) * 0.12;
	source += texture(TEXTURE, UV - vec2(0.0, texel.y)) * 0.12;
	source += texture(TEXTURE, UV + texel) * 0.06;
	source += texture(TEXTURE, UV - texel) * 0.06;
	source += texture(TEXTURE, UV + vec2(texel.x, -texel.y)) * 0.06;
	source += texture(TEXTURE, UV + vec2(-texel.x, texel.y)) * 0.06;
	source *= COLOR;
	source.rgb = mix(source.rgb, source.rgb * atmosphere_tint.rgb, tint_strength);
	float side_mask = smoothstep(0.0, edge_fade, UV.x) * smoothstep(0.0, edge_fade, 1.0 - UV.x);
	source.a *= side_mask;
	COLOR = source;
}
