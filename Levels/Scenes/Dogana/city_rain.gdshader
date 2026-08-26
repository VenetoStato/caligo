shader_type canvas_item;
render_mode blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.62;
uniform float fall_speed : hint_range(0.1, 3.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.16;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Versione compatibile anche con il renderer Compatibility: solo UV e TIME,
// nessun builtin screen-only che possa lasciare visibile il ColorRect bianco.
float rain_layer(vec2 uv, float density, float speed, float phase) {
	vec2 grid = vec2(density, density * 0.58);
	vec2 cell_uv = uv * grid;
	vec2 cell = floor(cell_uv);
	vec2 local = fract(cell_uv);
	float seed = hash21(cell + phase * 19.7);
	float vertical = fract(local.y + TIME * fall_speed * speed + seed);
	// Pioggia quasi verticale, leggermente spinta dal vento.
	float slant = wind * 0.19 + (seed - 0.5) * 0.04;
	float center_x = 0.5 + (vertical - 0.5) * slant;
	float body = 1.0 - smoothstep(0.012, 0.036, abs(local.x - center_x));
	float head = smoothstep(0.04, 0.15, vertical);
	float tail = 1.0 - smoothstep(0.58, 0.94, vertical);
	return body * head * tail * smoothstep(0.22, 0.68, seed);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float far_rain = rain_layer(uv, 78.0, 0.64, 0.13);
	float middle_rain = rain_layer(uv + vec2(0.071, 0.0), 49.0, 0.96, 0.47);
	float near_rain = rain_layer(uv + vec2(0.139, 0.0), 29.0, 1.32, 0.81);
	float rain = far_rain * 0.24 + middle_rain * 0.46 + near_rain * 0.72;
	vec3 rain_color = mix(vec3(0.22, 0.39, 0.49), vec3(0.71, 0.86, 0.90), near_rain);
	COLOR = vec4(rain_color, min(rain * intensity * 0.36, 0.32));
}
