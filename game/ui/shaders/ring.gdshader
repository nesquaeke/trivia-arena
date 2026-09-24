shader_type canvas_item;
// Halka sayaç. progress 1→0 azalır. Tik çizgileri + parlayan uç.
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col_a : source_color = vec4(1.0, 0.84, 0.48, 1.0);
uniform vec4 col_b : source_color = vec4(1.0, 0.36, 0.28, 1.0);
uniform float danger = 0.0;       // 0-1: kırmızıya kayış
uniform float thickness = 0.13;
uniform float ticks = 12.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.x, -p.y);            // tepeden saat yönü
	float a01 = fract(ang / 6.28318530718 + 1.0);
	float outer = 0.92; float inner = outer - thickness;
	float aa = fwidth(r) * 1.5;
	float ring = smoothstep(inner - aa, inner, r) * (1.0 - smoothstep(outer, outer + aa, r));
	float filled = step(a01, progress);
	vec3 cA = mix(col_a.rgb, col_b.rgb, danger);
	vec3 track = vec3(0.16, 0.07, 0.08);
	vec3 grad = mix(cA * 0.75, cA * 1.15, a01 / max(progress, 0.001));
	vec3 col = mix(track, grad, filled);
	// uçtaki parlama
	vec2 tip = vec2(sin(progress * 6.28318), -cos(progress * 6.28318)) * (outer - thickness * 0.5);
	float tipg = exp(-dot(p - tip, p - tip) * 90.0) * step(0.001, progress);
	// tikler
	float tk = abs(fract(a01 * ticks + 0.5) - 0.5);
	float tickmask = (1.0 - smoothstep(0.0, 0.035, tk)) * smoothstep(outer + 0.02, outer + 0.03, r) * (1.0 - smoothstep(0.985, 0.995, r));
	// iç disk
	float disk = 1.0 - smoothstep(inner - 0.06 - aa, inner - 0.06, r);
	vec3 diskc = vec3(0.07, 0.03, 0.035) + cA * 0.05 * (1.0 - r) + cA * pulse * 0.12;
	float glow = exp(-pow((r - (outer - thickness * 0.5)) / 0.12, 2.0)) * filled * (0.25 + pulse * 0.5);
	vec3 outc = diskc * disk;
	float alpha = disk * 0.92;
	outc = mix(outc, col, ring);
	alpha = max(alpha, ring);
	outc += cA * glow + vec3(1.0, 0.95, 0.85) * tipg;
	alpha = max(alpha, max(glow * 0.8, tipg));
	outc = mix(outc, col_a.rgb * 0.8, tickmask * 0.7);
	alpha = max(alpha, tickmask * 0.7);
	COLOR = vec4(outc, alpha * COLOR.a);
}
