shader_type spatial;
// Kale duvarı: boyalı tiyatro maketi taşı. Nesne uzayında üç yönlü (triplanar)
// tuğla örgüsü: sıralar kaydırılmış, harç çizgileri koyu ve hafif çukur, her
// taş biraz farklı tonda. Renk "tint" ile verilir (kalenin paleti).
uniform vec4 tint : source_color = vec4(0.9, 0.87, 0.8, 1.0);
uniform float brick_w = 0.085;
uniform float brick_h = 0.045;
uniform float mortar = 0.12;
uniform float variation = 0.12;
varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// tek düzlemde tuğla: x=renk çarpanı, y=harç maskesi
vec2 brick(vec2 uv) {
	vec2 s = uv / vec2(brick_w, brick_h);
	float row = floor(s.y);
	s.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(s);
	vec2 f = fract(s);
	float mx = mortar;
	float my = mortar * brick_w / brick_h;
	float edge = min(min(f.x, 1.0 - f.x) / mx, min(f.y, 1.0 - f.y) / my);
	float m = 1.0 - smoothstep(0.6, 1.0, edge);
	float v = hash(cell) * 2.0 - 1.0;
	return vec2(1.0 + v * variation, m);
}

void fragment() {
	vec3 n = abs(normalize(on));
	vec3 w = pow(n, vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 bx = brick(op.zy);
	vec2 by = brick(op.xz);
	vec2 bz = brick(op.xy);
	vec2 b = bx * w.x + by * w.y + bz * w.z;
	vec3 col = tint.rgb * b.x;
	col = mix(col, tint.rgb * 0.62, b.y * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.95, b.y);
	// harçta hafif gölge (sahte oyuk)
	AO = 1.0 - b.y * 0.35;
	AO_LIGHT_AFFECT = 0.6;
}
