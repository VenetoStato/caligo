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
uniform vec4 u_shadow_tint : source_color = vec4(0.2, 0.19, 0.38, 1.0);
uniform vec4 u_mid_tint : source_color = vec4(0.31, 0.62, 0.63, 1.0);
uniform vec4 u_highlight_tint : source_color = vec4(0.89, 0.97, 0.93, 1.0);
uniform float u_grade_strength : hint_range(0.0, 1.0) = 0.28;
uniform float u_exposure : hint_range(0.5, 1.6) = 1.08;

// Armonizzazione palette: le tinte del mondo vengono attratte verso tre ancore
// (acquamarina, viola, prugna). Gli accenti caldi luminosi restano fuori,
// perche' sono la lettura del gioco: personaggio, lanterne, colpo potenziato.
uniform float u_palette_unify : hint_range(0.0, 1.0) = 0.62;
uniform float u_palette_pastel : hint_range(0.0, 1.0) = 0.45;
uniform float u_palette_sat_cap : hint_range(0.0, 1.0) = 0.5;
uniform vec3 u_palette_hues = vec3(0.492, 0.752, 0.895);

uniform float u_chroma : hint_range(0.0, 3.0) = 0.55;
uniform float u_bloom : hint_range(0.0, 1.0) = 0.22;
uniform float u_bloom_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float u_haze : hint_range(0.0, 0.5) = 0.08;
uniform vec4 u_haze_color : source_color = vec4(0.55, 0.78, 0.82, 1.0);
uniform float u_ink_strength : hint_range(0.0, 0.6) = 0.18;
uniform float u_ink_threshold : hint_range(0.0, 0.4) = 0.075;
uniform float u_motion_breath : hint_range(0.0, 1.0) = 0.16;

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

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

float hue_distance(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}

// Spostamento minimo (con segno) dalla tinta corrente verso l'ancora.
float hue_shift_to(float from_hue, float anchor) {
	float shift = anchor - from_hue;
	if (shift > 0.5) {
		shift -= 1.0;
	}
	if (shift < -0.5) {
		shift += 1.0;
	}
	return shift;
}

// Un accento e' chiaro E saturo: personaggio, lanterne, colpo potenziato.
// Quei pixel restano fuori dall'armonizzazione, sono la lettura del gioco.
float accent_weight(vec3 color) {
	vec3 hsv = rgb2hsv(color);
	return smoothstep(0.46, 0.82, hsv.z) * smoothstep(0.26, 0.6, hsv.y);
}

vec3 harmonize_palette(vec3 color, float accent) {
	vec3 hsv = rgb2hsv(color);
	float anchor = u_palette_hues.x;
	float best = hue_distance(hsv.x, u_palette_hues.x);
	float dist_violet = hue_distance(hsv.x, u_palette_hues.y);
	if (dist_violet < best) {
		best = dist_violet;
		anchor = u_palette_hues.y;
	}
	if (hue_distance(hsv.x, u_palette_hues.z) < best) {
		anchor = u_palette_hues.z;
	}
	float unify = u_palette_unify * (1.0 - accent);
	hsv.x = fract(hsv.x + hue_shift_to(hsv.x, anchor) * unify + 1.0);
	// Pastello: satura solo fino al tetto e alza i mezzi toni lasciando i neri neri.
	hsv.y = mix(hsv.y, min(hsv.y, u_palette_sat_cap), u_palette_pastel * (1.0 - accent * 0.6));
	hsv.z = mix(hsv.z, pow(hsv.z, 0.86), u_palette_pastel);
	return hsv2rgb(hsv);
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

	// Respiro luminoso a costo costante. La profondita' viene dai piani reali:
	// niente blur screen-space, instabile su alcuni driver OpenGL Intel.
	float atmosphere_breath = 1.0 + sin(TIME * 0.32) * 0.012 * u_motion_breath;
	col *= atmosphere_breath;

	// Contorno percettivo screen-space: separa silhouette e architettura senza
	// trasformare l'immagine in un filtro cartoon o oscurare le texture.
	float center_luma = dot(sample_screen(SCREEN_UV), vec3(0.299, 0.587, 0.114));
	float edge_x = abs(center_luma - dot(sample_screen(SCREEN_UV + vec2(px.x * 1.5, 0.0)), vec3(0.299, 0.587, 0.114)));
	edge_x += abs(center_luma - dot(sample_screen(SCREEN_UV - vec2(px.x * 1.5, 0.0)), vec3(0.299, 0.587, 0.114)));
	float edge_y = abs(center_luma - dot(sample_screen(SCREEN_UV + vec2(0.0, px.y * 1.5)), vec3(0.299, 0.587, 0.114)));
	edge_y += abs(center_luma - dot(sample_screen(SCREEN_UV - vec2(0.0, px.y * 1.5)), vec3(0.299, 0.587, 0.114)));
	float ink = smoothstep(u_ink_threshold, u_ink_threshold + 0.22, max(edge_x, edge_y));
	col *= 1.0 - ink * u_ink_strength;

	// Soft bloom multi-tap più pieno.
	if (u_bloom > 0.001) {
		vec3 blur = vec3(0.0);
		blur += sample_screen(SCREEN_UV) * 0.18;
		blur += sample_screen(SCREEN_UV + vec2(px.x * 2.0, 0.0)) * 0.12;
		blur += sample_screen(SCREEN_UV - vec2(px.x * 2.0, 0.0)) * 0.12;
		blur += sample_screen(SCREEN_UV + vec2(0.0, px.y * 2.0)) * 0.12;
		blur += sample_screen(SCREEN_UV - vec2(0.0, px.y * 2.0)) * 0.12;
		blur += sample_screen(SCREEN_UV + vec2(px.x * 4.5, px.y * 2.5)) * 0.09;
		blur += sample_screen(SCREEN_UV - vec2(px.x * 4.5, px.y * 2.5)) * 0.09;
		blur += sample_screen(SCREEN_UV + vec2(px.x * 2.5, -px.y * 4.5)) * 0.08;
		blur += sample_screen(SCREEN_UV - vec2(px.x * 2.5, -px.y * 4.5)) * 0.08;
		float bloom_luma = dot(blur, vec3(0.299, 0.587, 0.114));
		float bloom_mask = smoothstep(u_bloom_threshold, u_bloom_threshold + 0.28, bloom_luma);
		col = mix(col, max(col, blur * 1.25), bloom_mask * u_bloom);
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col + vec3(u_shadow_lift), (1.0 - luma));

	// Split-tone a tre fasce: ombre indaco/viola, mezzi acqua, luci menta pallida.
	// Sostituisce la tinta mantenendo la luminanza, quindi unifica senza spegnere.
	float accent = accent_weight(col);
	vec3 ramp = luma < 0.5
		? mix(u_shadow_tint.rgb, u_mid_tint.rgb, clamp(luma * 2.0, 0.0, 1.0))
		: mix(u_mid_tint.rgb, u_highlight_tint.rgb, clamp((luma - 0.5) * 2.0, 0.0, 1.0));
	vec3 toned = ramp * (luma / max(dot(ramp, vec3(0.299, 0.587, 0.114)), 0.0001));
	col = mix(col, toned, u_grade_strength * (1.0 - accent * 0.88));
	col *= u_exposure;

	// Micro-sharpen sui mezzi toni (legge meglio sprite/animazioni).
	vec3 sharp = col * 2.0 - (
		sample_screen(SCREEN_UV + vec2(px.x, 0.0)) +
		sample_screen(SCREEN_UV - vec2(px.x, 0.0)) +
		sample_screen(SCREEN_UV + vec2(0.0, px.y)) +
		sample_screen(SCREEN_UV - vec2(0.0, px.y))
	) * 0.25;
	col = mix(col, sharp, 0.12 * (1.0 - abs(luma - 0.5) * 1.6));

	// Contrasto + saturazione.
	col = (col - vec3(0.5)) * u_contrast + vec3(0.5);
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, u_saturation);
	col = mix(col, vec3(luma), u_desaturate);

	col = harmonize_palette(col, accent);

	// Haze atmosferica ai bordi / basso schermo.
	float haze_mask = smoothstep(0.28, 1.05, edge) * 0.7 + smoothstep(0.5, 1.0, SCREEN_UV.y) * 0.5;
	col = mix(col, mix(col, u_haze_color.rgb, 0.4), haze_mask * u_haze);

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
