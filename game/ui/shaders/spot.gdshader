shader_type canvas_item;
// Yumuşak spot ışığı / hale (menü üzerindeki vurgu, kazanan). Toz zerreleri de süzülür.
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float intensity = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 radius = vec2(0.5, 0.5);
uniform float dust = 0.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	vec2 d = (UV - center) / radius;
	float g = exp(-dot(d, d) * 2.2);
	vec2 cell = floor(UV * vec2(60.0, 34.0) + vec2(0.0, TIME * 0.6));
	float h = hash(cell);
	vec2 f = fract(UV * vec2(60.0, 34.0) + vec2(0.0, TIME * 0.6)) - 0.5;
	float mote = step(0.965, h) * smoothstep(0.12, 0.0, length(f)) * (0.5 + 0.5 * sin(TIME * 2.0 + h * 40.0));
	COLOR = vec4(color.rgb, clamp(g * intensity + mote * dust * g, 0.0, 1.0) * COLOR.a);
}
