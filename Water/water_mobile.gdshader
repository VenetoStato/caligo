shader_type canvas_item;
render_mode unshaded;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.36, 0.43, 0.86);
uniform vec4 deep_color : source_color = vec4(0.025, 0.14, 0.24, 0.93);
uniform vec4 foam_color : source_color = vec4(0.62, 0.86, 0.88, 0.72);
uniform float water_depth = 1000.0;
uniform float surface_width = 4000.0;
uniform float micro_wave_strength : hint_range(0.0, 0.08) = 0.018;
uniform float reflection_strength : hint_range(0.0, 0.6) = 0.3;
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

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

// Rumore 1D morbido: serve a spezzare bordi e bande, che a occhio leggevano
// come righe disegnate sull'acqua invece che come superficie.
float noise11(float p) {
	float i = floor(p);
	float f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

float fbm(float p) {
	return noise11(p) * 0.55 + noise11(p * 2.17 + 11.3) * 0.28 + noise11(p * 4.41 + 3.7) * 0.17;
}

void fragment() {
	vec2 uv = UV;
	// Profondita' in pixel sotto la superficie ondulata: cosi' schiuma e
	// penetrazione della luce hanno uno spessore fisico, non percentuale.
	float depth_px = uv.y * water_depth;
	float along = uv.x * surface_width;

	float micro = sin(uv.x * 58.0 + TIME * 1.35) * 0.55;
	micro += sin(uv.x * 103.0 - TIME * 0.82) * 0.45;

	float ripples = ripple_value(uv, ripple_0);
	ripples += ripple_value(uv, ripple_1);
	ripples += ripple_value(uv, ripple_2);
	ripples += ripple_value(uv, ripple_3);

	float depth_gradient = smoothstep(0.0, 1.0, uv.y);
	vec4 water = mix(shallow_color, deep_color, depth_gradient);
	float wave_offset = micro * micro_wave_strength + ripples;

	// Rifrazione di cio' che sta dietro, appena percettibile.
	vec2 refraction_offset = vec2(wave_offset, cos(uv.x * 41.0 - TIME) * 0.003);
	vec3 scene_color = textureLod(
		screen_texture,
		clamp(SCREEN_UV + refraction_offset * refraction_strength * 8.0, vec2(0.001), vec2(0.999)),
		0.0
	).rgb;
	scene_color *= mix(vec3(0.72, 0.92, 0.96), vec3(0.25, 0.52, 0.68), depth_gradient);
	water.rgb = mix(scene_color, water.rgb, 0.78);

	// Riflesso speculare: campiona la scena specchiata attorno al pelo
	// dell'acqua. Vive solo nella fascia alta, come un riflesso vero.
	float mirror_fade = exp(-depth_px / 130.0);
	if (mirror_fade > 0.01) {
		float wobble = (fbm(along * 0.02 + TIME * 0.35) - 0.5) * 0.006;
		vec2 mirror_uv = SCREEN_UV + vec2(wobble, -2.0 * depth_px * SCREEN_PIXEL_SIZE.y);
		vec3 mirrored = textureLod(screen_texture, clamp(mirror_uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
		mirrored *= vec3(0.58, 0.78, 0.86);
		water.rgb = mix(water.rgb, mirrored, mirror_fade * reflection_strength);
	}

	// Luce che penetra: fascia chiara subito sotto la superficie.
	float subsurface = exp(-depth_px / 90.0);
	water.rgb += vec3(0.05, 0.13, 0.14) * subsurface * 0.55;

	// Caustiche lente e larghe al posto delle vecchie strisce ripetute.
	float caustic = fbm(along * 0.012 - TIME * 0.18) * fbm(along * 0.031 + TIME * 0.11);
	caustic *= exp(-depth_px / 220.0);
	water.rgb += vec3(0.13, 0.3, 0.3) * caustic * 0.16;
	water.rgb += wave_offset * (1.0 - uv.y * 0.65);

	// Schiuma dal bordo irregolare + menisco luminoso sul pelo dell'acqua.
	float foam_px = max(foam_width * water_depth, 4.0);
	float foam_edge = foam_px * (0.55 + 0.85 * fbm(along * 0.05 + TIME * 0.5));
	float foam = 1.0 - smoothstep(0.0, foam_edge, depth_px);
	foam *= 0.55 + 0.45 * fbm(along * 0.11 - TIME * 0.9);
	float meniscus = 1.0 - smoothstep(0.0, 2.6, depth_px);

	vec4 result = mix(water, foam_color, clamp(foam * 0.75 + abs(ripples) * 0.55, 0.0, 0.8));
	result.rgb += foam_color.rgb * meniscus * 0.55;

	float side_fade = smoothstep(0.0, 0.035, uv.x) * smoothstep(0.0, 0.035, 1.0 - uv.x);
	result.a *= side_fade;
	COLOR = result;
}
