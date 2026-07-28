shader_type canvas_item;

// Post-produzione Dogana: vignette, grain, grade lagunare, aberrazione, soft bloom.

uniform vec2 u_center_uv = vec2(0.5, 0.5);

uniform float u_vignette_strength : hint_range(0.0, 2.0) = 0.65;
uniform float u_vignette_softness : hint_range(0.01, 1.0) = 0.55;
uniform float u_vignette_radius   : hint_range(0.1, 2.0) = 1.10;

uniform float u_grain_amount : hint_range(0.0, 1.0) = 0.06;
uniform float u_grain_size   : hint_range(0.2, 6.0) = 2.20;
uniform float u_grain_speed  : hint_range(0.0, 10.0) = 0.65;
uniform float u_grain_midtones : hint_range(0.0, 2.0) = 1.0;
uniform float u_grain_shadows  : hint_range(0.0, 1.0) = 0.25;
uniform float u_grain_highs    : hint_range(0.0, 1.0) = 0.35;

uniform float u_desaturate : hint_range(0.0, 1.0) = 0.05;
uniform float u_shadow_lift : hint_range(0.0, 0.2) = 0.04;

uniform float u_contrast : hint_range(0.5, 1.5) = 1.06;
uniform float u_saturation : hint_range(0.0, 2.0) = 0.92;
uniform vec4 u_shadow_tint : source_color = vec4(0.12, 0.28, 0.32, 1.0);
uniform vec4 u_highlight_tint : source_color = vec4(0.95, 0.92, 0.82, 1.0);
uniform float u_grade_strength : hint_range(0.0, 1.0) = 0.28;

uniform float u_chroma : hint_range(0.0, 3.0) = 0.55;
uniform float u_bloom : hint_range(0.0, 1.0) = 0.22;
uniform float u_bloom_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float u_haze : hint_range(0.0, 0.5) = 0.08;
uniform vec4 u_haze_color : source_color = vec4(0.55, 0.78, 0.82, 1.0);

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 u_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

vec3 overlay(vec3 base, float blend) {
	float b = clamp(blend * 0.5 + 0.5, 0.0, 1.0);
	vec3 res;
	for (int k = 0; k < 3; k++) {
		float c = base[k];
		res[k] = (c < 0.5) ? (2.0 * c * b) : (1.0 - 2.0 * (1.0 - c) * (1.0 - b));
	}
	return res;
}

vec3 sample_screen(vec2 uv) {
	return texture(screen_tex, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 dir = normalize(SCREEN_UV - u_center_uv + vec2(0.0001));
	float chroma = u_chroma * 0.00115;

	// Aberrazione cromatica leggera ai bordi.
	float edge = length((SCREEN_UV - vec2(0.5)) * vec2(1.4, 1.0));
	float ca = chroma * smoothstep(0.15, 0.85, edge);
	float r = sample_screen(SCREEN_UV + dir * ca).r;
	float g = sample_screen(SCREEN_UV).g;
	float b = sample_screen(SCREEN_UV - dir * ca).b;
	vec3 col = vec3(r, g, b) * u_tint.rgb;

	// Soft bloom a basso costo (campioni intorno alle luci).
	if (u_bloom > 0.001) {
		vec3 blur = sample_screen(SCREEN_UV);
		blur += sample_screen(SCREEN_UV + vec2(px.x * 2.5, 0.0));
		blur += sample_screen(SCREEN_UV - vec2(px.x * 2.5, 0.0));
		blur += sample_screen(SCREEN_UV + vec2(0.0, px.y * 2.5));
		blur += sample_screen(SCREEN_UV - vec2(0.0, px.y * 2.5));
		blur += sample_screen(SCREEN_UV + vec2(px.x * 4.0, px.y * 3.0));
		blur += sample_screen(SCREEN_UV - vec2(px.x * 4.0, px.y * 3.0));
		blur *= 0.142857;
		float bloom_luma = dot(blur, vec3(0.299, 0.587, 0.114));
		float bloom_mask = smoothstep(u_bloom_threshold, u_bloom_threshold + 0.25, bloom_luma);
		col = mix(col, max(col, blur * 1.15), bloom_mask * u_bloom);
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col + vec3(u_shadow_lift), (1.0 - luma));

	// Color grade: ombre teal / highlights caldi (laguna / pietra).
	vec3 graded = mix(u_shadow_tint.rgb * col, u_highlight_tint.rgb * col, luma);
	col = mix(col, graded, u_grade_strength);

	// Contrasto + saturazione.
	col = (col - vec3(0.5)) * u_contrast + vec3(0.5);
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, u_saturation);
	col = mix(col, vec3(luma), u_desaturate);

	// Haze atmosferica ai bordi / basso schermo.
	float haze_mask = smoothstep(0.35, 1.05, edge) * 0.65 + smoothstep(0.55, 1.0, SCREEN_UV.y) * 0.45;
	col = mix(col, mix(col, u_haze_color.rgb, 0.35), haze_mask * u_haze);

	// Vignette cinematografica.
	vec2 p = SCREEN_UV - u_center_uv;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	p.x *= aspect;
	float dist = pow(pow(abs(p.x), 1.35) + pow(abs(p.y), 1.35), 1.0 / 1.35);
	float vig = smoothstep(u_vignette_radius, u_vignette_radius - u_vignette_softness, dist);
	col *= mix(1.0 - u_vignette_strength, 1.0, vig);

	// Grain film.
	vec2 pix = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 uv1 = (pix / (u_grain_size * 1.0)) + vec2(TIME * u_grain_speed, -TIME * (u_grain_speed * 0.73));
	float n1 = noise(uv1);
	vec2 uv2 = (pix / (u_grain_size * 0.55)) + vec2(-TIME * (u_grain_speed * 0.61), TIME * (u_grain_speed * 0.49));
	float n2 = noise(uv2);
	float g_noise = ((n1 * 0.7 + n2 * 0.3) - 0.5) * 2.0;
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	float mid = pow(clamp(1.0 - abs(luma - 0.5) * 2.0, 0.0, 1.0), u_grain_midtones);
	float tone_mask = clamp(mid + smoothstep(0.0, 0.25, luma) * u_grain_shadows + (1.0 - smoothstep(0.75, 1.0, luma)) * u_grain_highs, 0.0, 1.0);
	col = mix(col, overlay(col, g_noise), u_grain_amount * tone_mask);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.2)), 1.0);
}
