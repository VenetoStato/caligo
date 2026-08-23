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

vec2 gradient_dir(vec2 cell) {
	float angle = hash(cell) * 6.28318530718;
	return vec2(cos(angle), sin(angle));
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(gradient_dir(i), f);
	float b = dot(gradient_dir(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(gradient_dir(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(gradient_dir(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.72 + 0.5;
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
	// Celle molto allungate in orizzontale: veli lagunari, non blocchi quadrati.
	vec2 coord = vec2(v_world.x * u_scale * 0.44, v_world.y * u_scale * 1.35) + wind * TIME;
	vec2 warp = vec2(fbm(coord + vec2(0.0, TIME * 0.02)), fbm(coord + vec2(3.1, -TIME * 0.015)));
	vec2 detail_coord = vec2(coord.x * 0.82 + coord.y * 0.57, -coord.x * 0.57 + coord.y * 0.82);
	float n = fbm(coord + warp * 0.82) * 0.72 + fbm(detail_coord * 1.7 - warp * 0.35) * 0.28;

	// Più densa verso il suolo / acqua, rarefatta in alto.
	float height_t = clamp((u_ground_y - v_world.y) / max(u_ground_y - u_ceiling_y, 1.0), 0.0, 1.0);
	float height_mask = mix(1.0 - u_height_soft, 1.0, pow(1.0 - height_t, 1.35));

	// Disturbo locale: apre un foro soft. Niente scia colorata.
	float speed = length(u_player_vel);
	vec2 to_player = v_world - u_player_world;
	float dist = length(to_player);
	float wake_r = u_disturb_radius * (1.0 + clamp(speed / 280.0, 0.0, 0.6));
	float hole = 1.0 - smoothstep(wake_r * 0.4, wake_r, dist);

	float density = smoothstep(0.36, 0.72, n) * u_density * height_mask;
	density *= 1.0 - hole * u_disturb_strength * (0.45 + u_layer * 0.35);

	// Bordo molto largo: un fade corto lasciava vedere il quad come un rettangolo.
	float edge = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);
	density *= smoothstep(0.0, 0.18, edge);

	COLOR = vec4(u_color.rgb, clamp(density * u_color.a, 0.0, 1.0));
}
