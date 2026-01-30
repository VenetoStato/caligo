shader_type canvas_item;

// Effetto "sotto acqua": distorsione a onde + leggero shift colore (rifrazione)
uniform float strength : hint_range(0.0, 0.04) = 0.012;
uniform float speed : hint_range(0.0, 4.0) = 1.2;
uniform float wave_scale : hint_range(2.0, 25.0) = 8.0;
uniform float tint_strength : hint_range(0.0, 0.15) = 0.04;  // leggero blu/verde acqua

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// Più onde sovrapposte = effetto ripple/acqua più organico
	float wave1 = sin(uv.x * wave_scale + t) * sin(uv.y * wave_scale * 0.7 + t * 0.9);
	float wave2 = sin((uv.x + uv.y) * wave_scale * 0.5 + t * 1.3) * 0.6;
	float wave3 = sin(uv.y * wave_scale * 1.2 - t * 0.8) * 0.4;
	float combined = (wave1 + wave2 + wave3) / 2.0;
	uv.x += combined * strength;
	uv.y += sin(uv.x * wave_scale * 0.8 + t * 1.1) * strength * 0.7;
	vec4 tex = texture(TEXTURE, uv) * COLOR;
	// Leggera tinta acqua (blu-verde) come rifrazione
	tex.r = mix(tex.r, tex.r * 0.92, tint_strength);
	tex.g = mix(tex.g, tex.g * 1.02, tint_strength);
	tex.b = mix(tex.b, tex.b * 1.08, tint_strength);
	COLOR = tex;
}

