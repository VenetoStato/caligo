shader_type canvas_item;

// Distorsione leggerissima per simulare acqua sui pesci sotto
uniform float strength : hint_range(0.0, 0.03) = 0.008;
uniform float speed : hint_range(0.0, 6.0) = 1.5;
uniform float scale : hint_range(0.5, 20.0) = 6.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// piccola distorsione sinusoidale
	uv.y += sin((uv.x * scale) + t) * strength;
	uv.x += sin((uv.y * scale * 0.9) + t * 1.1) * (strength * 0.6);
	COLOR = texture(TEXTURE, uv) * COLOR;
}

