shader_type spatial;
// Conquest haritasının denizi: koyu mavi saten kumaş. Kıvrımlar yavaşça
// kayar, parlaklık dalga sırtlarında yakalanır.
uniform vec4 deep : source_color = vec4(0.06, 0.20, 0.32, 1.0);
uniform vec4 light : source_color = vec4(0.22, 0.52, 0.66, 1.0);
uniform float scale = 1.6;
uniform float speed = 0.25;
uniform float grid = 1.1;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * scale;
	float t = TIME * speed;
	float f = sin(p.x * 1.3 + t * 2.0 + sin(p.y * 0.8 + t)) * 0.5 + 0.5;
	float g = sin(p.y * 2.1 - t * 1.4 + sin(p.x * 0.6 - t * 0.7) * 1.4) * 0.5 + 0.5;
	float band = smoothstep(0.55, 1.0, f * g);
	vec3 col = mix(deep.rgb, light.rgb, band * 0.55 + f * 0.12);
	// eski harita ızgarası: enlem-boylam çizgileri, kumaşa altın iplikle işlenmiş
	vec2 gd = abs(fract(wp.xz / grid) - 0.5);
	float line = smoothstep(0.487, 0.497, max(gd.x, gd.y));
	col = mix(col, vec3(0.85, 0.68, 0.36), line * 0.22);
	ALBEDO = col;
	ROUGHNESS = 0.32 - band * 0.12;
	SPECULAR = 0.7;
	// saten parlaklığı: normali kıvrımlarla hafifçe eğ
	vec3 n = normalize(vec3(cos(p.x * 1.3 + t * 2.0) * 0.18, 1.0, cos(p.y * 2.1 - t * 1.4) * 0.14));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
