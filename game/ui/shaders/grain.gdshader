shader_type canvas_item;
// Tüm ekranın üstüne ince film greni + köşe karartması. Etkiyi strength ile ayarla.
uniform float grain = 0.045;
uniform float vignette = 0.38;
uniform float flicker = 0.015;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float g = hash(floor(FRAGCOORD.xy / 1.5) + floor(TIME * 24.0) * 13.1) - 0.5;
	vec2 q = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(q * vec2(1.0, 1.25)));
	float fl = (hash(vec2(floor(TIME * 12.0), 3.0)) - 0.5) * flicker;
	float a = v * vignette + abs(g) * grain + max(0.0, fl);
	COLOR = vec4(vec3(g > 0.0 ? 1.0 : 0.0) * (1.0 - v) * 0.3, a);
}
