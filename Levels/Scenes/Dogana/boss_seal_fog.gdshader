shader_type canvas_item;
render_mode unshaded;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV;
	float t = TIME * 0.22;
	float broad = noise(vec2(p.x * 3.2 + t, p.y * 7.0 - t * 0.35));
	float detail = noise(vec2(p.x * 8.0 - t * 1.4, p.y * 15.0 + t * 0.55));
	float wisps = smoothstep(0.25, 0.88, broad * 0.72 + detail * 0.42);
	float side_fade = smoothstep(0.0, 0.34, p.x) * smoothstep(0.0, 0.34, 1.0 - p.x);
	float broken_edge = 0.68 + 0.32 * noise(vec2(p.y * 11.0 + t, t));
	float alpha = (0.2 + wisps * 0.78) * side_fade * broken_edge;
	vec3 cold = mix(vec3(0.15, 0.43, 0.52), COLOR.rgb, broad);
	COLOR = vec4(cold, COLOR.a * alpha);
}
