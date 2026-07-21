shader_type canvas_item;
render_mode unshaded;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.30, 0.36, 0.48);
uniform vec4 deep_color : source_color = vec4(0.015, 0.09, 0.16, 0.74);
uniform vec4 foam_color : source_color = vec4(0.52, 0.80, 0.82, 0.52);
uniform float micro_wave_strength : hint_range(0.0, 0.08) = 0.018;
uniform float reflection_strength : hint_range(0.0, 0.5) = 0.09;
uniform float foam_width : hint_range(0.001, 0.2) = 0.035;
uniform float refraction_strength : hint_range(0.0, 0.04) = 0.012;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// x=center UV, y=age, z=amplitude, w=radius UV. Negative age disables a ripple.
uniform vec4 ripple_0 = vec4(0.0, -1.0, 0.0, 0.1);
uniform vec4 ripple_1 = vec4(0.0, -1.0, 0.0, 0.1);
uniform vec4 ripple_2 = vec4(0.0, -1.0, 0.0, 0.1);
uniform vec4 ripple_3 = vec4(0.0, -1.0, 0.0, 0.1);

float ripple_value(vec2 uv, vec4 ripple) {
	if (ripple.y < 0.0) {
		return 0.0;
	}
	float radius = max(ripple.w, 0.001);
	float distance_from_ring = abs(abs(uv.x - ripple.x) - ripple.y * 0.18);
	float envelope = max(0.0, 1.0 - distance_from_ring / radius);
	float life = max(0.0, 1.0 - ripple.y * 0.75);
	return sin(distance_from_ring * 95.0 - ripple.y * 15.0) * envelope * life * ripple.z;
}

void fragment() {
	vec2 uv = UV;
	float micro = sin(uv.x * 58.0 + TIME * 1.35) * 0.55;
	micro += sin(uv.x * 103.0 - TIME * 0.82) * 0.45;

	float ripples = ripple_value(uv, ripple_0);
	ripples += ripple_value(uv, ripple_1);
	ripples += ripple_value(uv, ripple_2);
	ripples += ripple_value(uv, ripple_3);

	float depth_gradient = smoothstep(0.0, 1.0, uv.y);
	vec4 water = mix(shallow_color, deep_color, depth_gradient);
	float wave_offset = micro * micro_wave_strength + ripples;
	vec2 refraction_offset = vec2(wave_offset, cos(uv.x * 41.0 - TIME) * 0.003);
	vec3 scene_color = textureLod(
		screen_texture,
		clamp(SCREEN_UV + refraction_offset * refraction_strength * 8.0, vec2(0.001), vec2(0.999)),
		0.0
	).rgb;
	scene_color *= mix(vec3(0.72, 0.92, 0.96), vec3(0.25, 0.52, 0.68), depth_gradient);
	water.rgb = mix(scene_color, water.rgb, 0.42);
	float reflection = pow(max(0.0, 1.0 - uv.y), 3.0);
	water.rgb += reflection * reflection_strength;
	water.rgb += wave_offset * (1.0 - uv.y * 0.65);

	float foam = 1.0 - smoothstep(0.0, foam_width, uv.y);
	foam *= 0.65 + 0.35 * sin(uv.x * 72.0 + TIME * 1.8);
	COLOR = mix(water, foam_color, clamp(foam + abs(ripples) * 0.55, 0.0, 0.85));
}
