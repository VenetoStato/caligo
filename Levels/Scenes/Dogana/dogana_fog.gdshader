shader_type canvas_item;
// Nebbia ambientale world-space: deriva lenta + disturbo locale del player.
// Non segue il personaggio: interagisce solo vicino a lui.

varying vec2 v_world;

uniform vec4 u_color : source_color = vec4(0.72, 0.86, 0.88, 0.22);
uniform float u_density : hint_range(0.0, 1.5) = 0.55;
uniform float u_scale : hint_range(0.0005, 0.02) = 0.0032;
uniform vec2 u_wind = vec2(0.018, 0.004);
uniform float u_height_soft : hint_range(0.0, 1.0) = 0.55;
uniform float u_ground_y = 540.0;
uniform float u_ceiling_y = -200.0;
uniform vec2 u_player_world = vec2(0.0, 0.0);
uniform vec2 u_player_vel = vec2(0.0, 0.0);
uniform float u_disturb_radius : hint_range(40.0, 400.0) = 140.0;
uniform float u_disturb_strength : hint_range(0.0, 1.0) = 0.55;
uniform float u_layer = 0.0; // 0 far, 1 near
uniform int u_octaves = 4;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 coord) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= u_octaves) {
			break;
		}
		value += value_noise(coord) * amp;
		coord *= 2.05;
		amp *= 0.5;
	}
	return value;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 wind = u_wind * (0.55 + u_layer * 0.9);
	vec2 coord = v_world * u_scale + wind * TIME;
	vec2 warp = vec2(fbm(coord + vec2(0.0, TIME * 0.02)), fbm(coord + vec2(3.1, -TIME * 0.015)));
	float n = fbm(coord + warp * 1.35);

	// Più densa verso il suolo / acqua, rarefatta in alto.
	float height_t = clamp((u_ground_y - v_world.y) / max(u_ground_y - u_ceiling_y, 1.0), 0.0, 1.0);
	float height_mask = mix(1.0 - u_height_soft, 1.0, pow(1.0 - height_t, 1.35));

	// Disturbo locale: il player apre e sposta la nebbia intorno a sé.
	float speed = length(u_player_vel);
	vec2 to_player = v_world - u_player_world;
	float dist = length(to_player);
	float wake_r = u_disturb_radius * (1.0 + clamp(speed / 220.0, 0.0, 1.2));
	float hole = 1.0 - smoothstep(wake_r * 0.35, wake_r, dist);

	// Sposta il campionamento nella direzione opposta alla corsa (scia dietro).
	vec2 push = vec2(0.0);
	if (speed > 12.0) {
		push = normalize(u_player_vel) * (speed * 0.0018);
	}
	float n2 = fbm(coord - push * hole * 4.0 + warp);
	n = mix(n, n2, hole * 0.65);

	float density = smoothstep(0.28, 0.78, n) * u_density * height_mask;
	density *= 1.0 - hole * u_disturb_strength * (0.55 + u_layer * 0.45);

	// Bordo soft del volume: evita taglio netto ai limiti del poligono.
	float edge = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);
	density *= smoothstep(0.0, 0.08, edge);

	COLOR = vec4(u_color.rgb, clamp(density * u_color.a, 0.0, 1.0));
}
