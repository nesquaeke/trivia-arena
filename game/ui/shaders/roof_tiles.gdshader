shader_type spatial;
// Çatı ve kubbe: yuvarlak uçlu kiremit sıraları (pul pul). Sıralar
// yüksekliğe göre, taşma açıya göre; her kiremidin altı hafif koyu.
uniform vec4 tint : source_color = vec4(0.18, 0.38, 0.53, 1.0);
uniform float rows = 42.0;
uniform float cols = 18.0;
varying vec3 op;

void vertex() { op = VERTEX; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	float ang = atan(op.z, op.x) / 6.2831853 + 0.5;
	vec2 s = vec2(ang * cols, op.y * rows);
	float row = floor(s.y);
	s.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(s);
	vec2 cell = floor(s);
	// pulun yuvarlak alt kenarı
	float d = length(vec2((f.x - 0.5) * 1.1, f.y * 0.9));
	float shade = smoothstep(0.35, 0.62, d);
	float v = hash(cell) * 0.16 - 0.08;
	vec3 col = tint.rgb * (1.0 + v);
	col = mix(col, tint.rgb * 0.55, shade * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.55 + shade * 0.3;
	METALLIC = 0.05;
}
