shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.62;
uniform float fall_speed : hint_range(0.1, 3.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.16;
uniform float aspect_ratio : hint_range(0.5, 3.0) = 1.777778;
uniform float waterline_uv = 2.0;
uniform float waterline_softness : hint_range(0.0, 0.03) = 0.004;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float waterline_noise(float x) {
	float cell = floor(x);
	float amount = fract(x);
	amount = amount * amount * (3.0 - 2.0 * amount);
	float left = hash21(vec2(cell, 19.73));
	float right = hash21(vec2(cell + 1.0, 19.73));
	return mix(left, right, amount);
}

float streak_layer(vec2 uv, float columns, float speed, float phase, float width) {
	float aspect = aspect_ratio;
	vec2 p = vec2(uv.x * aspect, uv.y);
	// Le UV canvas crescono verso il basso; sottrarre il tempo fa scorrere
	// visivamente le celle dall'alto verso il basso.
	p.y -= TIME * fall_speed * speed;
	// Apply slant after the animated Y. Previously X used the original screen Y,
	// so streaks travelled inside almost fixed vertical columns. Each depth now
	// has a slightly different natural drift even with zero wind.
	float layer_slant = wind * 0.16 + (phase - 0.5) * 0.038;
	p.x -= p.y * layer_slant;
	p.x += sin(TIME * (0.31 + speed * 0.17) + phase * 11.0) * 0.012;
	vec2 grid = vec2(columns * aspect, columns * 0.54);
	vec2 id = floor(p * grid);
	vec2 q = fract(p * grid) - 0.5;
	float seed = hash21(id + phase * 31.7);
	q.x += (seed - 0.5) * 0.58;
	q.x += q.y * (wind * 0.42);
	float line = 1.0 - smoothstep(width, width * 2.5, abs(q.x));
	float segment = smoothstep(-0.49, -0.18, q.y) * (1.0 - smoothstep(0.08, 0.49, q.y));
	// Fewer decorative streaks: the world-space drops below are now the main
	// readable rain and almost every one produces a real surface contact.
	float active = smoothstep(0.68, 0.93, seed);
	return line * segment * active;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float far_rain = streak_layer(uv, 92.0, 0.44, 0.13, 0.035);
	float mid_rain = streak_layer(uv + vec2(0.073, 0.0), 58.0, 0.76, 0.47, 0.045);
	float near_rain = streak_layer(uv + vec2(0.151, 0.0), 34.0, 1.06, 0.81, 0.052);
	float rain = far_rain * 0.16 + mid_rain * 0.34 + near_rain * 0.58;
	float shimmer = 0.76 + hash21(floor(FRAGCOORD.xy * 0.5)) * 0.24;
	vec3 rain_color = mix(vec3(0.28, 0.46, 0.55), vec3(0.68, 0.84, 0.88), near_rain * 0.7);
	// The screen overlay used to continue under the water even though the
	// physical drops stopped there. Fade every streak exactly at the dynamic
	// world-space waterline supplied by dogana_depth_layers.gd.
	// A shallow, smoothly varying penetration avoids revealing the water mask
	// as one perfectly straight cutoff line.
	float broad_variation = (waterline_noise(uv.x * 13.0 + 4.7) - 0.5) * 0.012;
	float fine_variation = (waterline_noise(uv.x * 47.0) - 0.5) * 0.011;
	float local_waterline = waterline_uv + 0.012 + broad_variation + fine_variation;
	float above_water = 1.0 - smoothstep(
		local_waterline - waterline_softness,
		local_waterline + waterline_softness,
		uv.y
	);
	// Procedural streaks cannot emit gameplay events. Clear them before the
	// contact band so they never form a fake row of impacts on the surface.
	// World-space Line2D drops cross this final gap and each owns a real ripple.
	float contact_clearance = 1.0 - smoothstep(
		local_waterline - 0.065,
		local_waterline - 0.018,
		uv.y
	);
	float alpha = clamp(rain * intensity * shimmer, 0.0, 0.24) * above_water * contact_clearance;
	COLOR = vec4(rain_color, alpha);
}
