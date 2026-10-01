shader_type canvas_item;
render_mode blend_mix;

uniform float edge_fade : hint_range(0.02, 0.35) = 0.16;
uniform float vertical_fade : hint_range(0.0, 0.35) = 0.0;
uniform vec4 atmosphere_tint : source_color = vec4(0.82, 0.93, 0.97, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float left_mask = smoothstep(0.0, edge_fade, UV.x);
	float right_mask = smoothstep(0.0, edge_fade, 1.0 - UV.x);
	float top_mask = smoothstep(0.0, max(vertical_fade, 0.001), UV.y);
	float bottom_mask = smoothstep(0.0, max(vertical_fade, 0.001), 1.0 - UV.y);
	float vertical_mask = mix(1.0, top_mask * bottom_mask, step(0.001, vertical_fade));
	source.rgb = mix(source.rgb, source.rgb * atmosphere_tint.rgb, tint_strength);
	source.a *= left_mask * right_mask * vertical_mask;
	COLOR = source;
}
