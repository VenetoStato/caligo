shader_type canvas_item;

// 0..1: centro vignette (in UV). Lo aggiorniamo dalla camera.
uniform vec2 u_center_uv = vec2(0.5, 0.5);

// Vignette (più “HK”)
uniform float u_vignette_strength : hint_range(0.0, 2.0) = 0.65;
uniform float u_vignette_softness : hint_range(0.01, 1.0) = 0.55;
uniform float u_vignette_radius   : hint_range(0.1, 2.0) = 1.10;

// Grain (più fine e controllato)
uniform float u_grain_amount : hint_range(0.0, 1.0) = 0.06;   // abbassato di default
uniform float u_grain_size   : hint_range(0.2, 6.0) = 2.20;   // più grande = più fine (perché campioniamo diverso)
uniform float u_grain_speed  : hint_range(0.0, 10.0) = 0.65;  // meno flicker

// Maschera grain sui mezzi toni
uniform float u_grain_midtones : hint_range(0.0, 2.0) = 1.0;  // 1 = standard
uniform float u_grain_shadows  : hint_range(0.0, 1.0) = 0.25; // quanto grain nei neri
uniform float u_grain_highs    : hint_range(0.0, 1.0) = 0.35; // quanto grain nelle alte luci

// Opzione: lieve desaturazione tipo “film”
uniform float u_desaturate : hint_range(0.0, 1.0) = 0.05;

// Opzione: leggero “lift” ombre (HK spesso non ha neri totalmente schiacciati)
uniform float u_shadow_lift : hint_range(0.0, 0.2) = 0.04;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 u_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// hash veloce
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// noise “value” con smoothing
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

// overlay blend (come Photoshop)
vec3 overlay(vec3 base, float blend) {
	// blend in [-1..1] circa; convertiamo in [0..1]
	float b = clamp(blend * 0.5 + 0.5, 0.0, 1.0);
	vec3 res;
	for (int k = 0; k < 3; k++) {
		float c = base[k];
		res[k] = (c < 0.5) ? (2.0 * c * b) : (1.0 - 2.0 * (1.0 - c) * (1.0 - b));
	}
	return res;
}

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV) * u_tint;

	// --- Luma / maschere tonalità ---
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));

	// lift ombre (molto leggero)
	col.rgb = mix(col.rgb, col.rgb + vec3(u_shadow_lift), (1.0 - luma));

	// --- VIGNETTE più “cinematica” ---
	vec2 p = SCREEN_UV - u_center_uv;

	// aspect correction
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	p.x *= aspect;

	// “squircle-ish” per HK: un po’ meno circolare
	float dist = pow(pow(abs(p.x), 1.35) + pow(abs(p.y), 1.35), 1.0 / 1.35);

	// vig: 1 al centro -> 0 ai bordi
	float vig = smoothstep(u_vignette_radius, u_vignette_radius - u_vignette_softness, dist);
	float darken = mix(1.0 - u_vignette_strength, 1.0, vig);
	col.rgb *= darken;

	// --- GRAIN “film-like”: 2 layers, più fine, meno flicker ---
	// Usiamo coordinate in pixel space, poi scalate:
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE; // pixel coords

	// Layer fine
	vec2 uv1 = (px / (u_grain_size * 1.0)) + vec2(TIME * u_grain_speed, -TIME * (u_grain_speed * 0.73));
	float n1 = noise(uv1);

	// Layer micro (più fine ancora, meno intenso)
	vec2 uv2 = (px / (u_grain_size * 0.55)) + vec2(-TIME * (u_grain_speed * 0.61), TIME * (u_grain_speed * 0.49));
	float n2 = noise(uv2);

	// Combine + center to [-1..1]
	float g = ((n1 * 0.7 + n2 * 0.3) - 0.5) * 2.0;

	// Maschera: più grain sui mezzi toni, meno su ombre/alte luci
	// midtone bell: picco ~0.5
	float mid = 1.0 - abs(luma - 0.5) * 2.0;      // 0 ai bordi (0/1), 1 a 0.5
	mid = pow(clamp(mid, 0.0, 1.0), u_grain_midtones);

	float shadow_mask = smoothstep(0.0, 0.25, luma) * u_grain_shadows;       // 0 nei neri, cresce poco
	float high_mask   = (1.0 - smoothstep(0.75, 1.0, luma)) * u_grain_highs; // meno in highlight
	float tone_mask   = clamp(mid + shadow_mask + high_mask, 0.0, 1.0);

	float grain_amt = u_grain_amount * tone_mask;

	// Applica grain in overlay (molto più naturale di additivo)
	col.rgb = mix(col.rgb, overlay(col.rgb, g), grain_amt);

	// --- Desaturazione leggera ---
	luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(luma), u_desaturate);

	COLOR = col;
}
