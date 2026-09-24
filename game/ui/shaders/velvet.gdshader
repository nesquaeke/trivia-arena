shader_type canvas_item;
// Kadife perde: kıvrımlar, ışık, altta altın saçak. drop 0→1 perdenin inişi.
uniform float drop : hint_range(0.0, 1.0) = 1.0;
uniform vec4 velvet : source_color = vec4(0.42, 0.05, 0.10, 1.0);
uniform vec4 fringe : source_color = vec4(0.86, 0.66, 0.30, 1.0);
uniform float folds = 22.0;
uniform float sway = 1.0;
uniform vec2 size = vec2(1920.0, 1080.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float edge = drop * 1.08 + 0.02 * sin(uv.x * 18.0 + TIME * 1.2) * sway;   // alt kenar dalgası
	if (uv.y > edge) { discard; }
	float x = uv.x * folds + 0.35 * sin(uv.y * 3.0 + TIME * 0.6) * sway + 0.18 * sin(uv.x * 7.0);
	float f = 0.5 + 0.5 * sin(x * 3.14159);
	float shade = pow(f, 0.65);
	float spec = pow(f, 18.0) * 0.55;
	vec3 col = velvet.rgb * (0.30 + 0.95 * shade) + vec3(1.0, 0.55, 0.5) * spec * 0.35;
	// üstten gelen spot
	float spot = exp(-pow((uv.x - 0.5) / 0.45, 2.0)) * (0.55 + 0.45 * uv.y);
	col *= 0.55 + 0.75 * spot;
	// alt kenarda gölge + saçak
	float dist = edge - uv.y;
	float fr = smoothstep(0.0, 0.004, dist) * (1.0 - smoothstep(0.028, 0.032, dist));
	float tassel = step(0.5, fract(uv.x * 160.0)) * (1.0 - smoothstep(0.0, 0.02, dist));
	col = mix(col, fringe.rgb * (0.7 + 0.5 * f), max(fr, tassel * 0.7));
	col *= 1.0 - (hash(floor(FRAGCOORD.xy) + floor(TIME * 20.0)) - 0.5) * 0.06;
	COLOR = vec4(col, 1.0);
}
