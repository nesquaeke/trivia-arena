shader_type canvas_item;
// Tiyatro ampulleri: dikdörtgen çerçeve (ya da tek sıra) boyunca kovalamaca ışıkları.
uniform vec2 size = vec2(600.0, 200.0);
uniform float spacing = 28.0;
uniform float radius = 4.2;
uniform float inset = 10.0;
uniform vec4 bulb_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float chase = 5.0;        // hız
uniform float group = 3.0;        // kaç ampulde bir yanar
uniform float base_level = 0.35;  // sönük ampul parlaklığı
uniform bool row_only = false;    // true: yalnız ortadan tek sıra
uniform float intro = 1.0;        // 0→1: ampuller sırayla yanar

vec2 perim_point(float s, vec2 a, vec2 b) {
	float w = b.x - a.x; float h = b.y - a.y;
	float P = 2.0 * (w + h);
	s = mod(s, P);
	if (s < w) return vec2(a.x + s, a.y);
	s -= w;
	if (s < h) return vec2(b.x, a.y + s);
	s -= h;
	if (s < w) return vec2(b.x - s, b.y);
	s -= w;
	return vec2(a.x, b.y - s);
}
float perim_param(vec2 p, vec2 a, vec2 b) {
	float w = b.x - a.x; float h = b.y - a.y;
	vec2 q = clamp(p, a, b);
	float dl = q.x - a.x, dr = b.x - q.x, dt = q.y - a.y, db = b.y - q.y;
	float m = min(min(dl, dr), min(dt, db));
	if (m == dt) return q.x - a.x;
	if (m == dr) return w + (q.y - a.y);
	if (m == db) return w + h + (b.x - q.x);
	return 2.0 * w + h + (b.y - q.y);
}
void fragment() {
	vec2 p = UV * size;
	vec2 a = vec2(inset); vec2 b = size - vec2(inset);
	float idx; vec2 c; float count;
	if (row_only) {
		count = floor((b.x - a.x) / spacing) + 1.0;
		float gap = (b.x - a.x) / max(1.0, count - 1.0);
		idx = clamp(floor((p.x - a.x) / gap + 0.5), 0.0, count - 1.0);
		c = vec2(a.x + idx * gap, size.y * 0.5);
	} else {
		float P = 2.0 * ((b.x - a.x) + (b.y - a.y));
		count = floor(P / spacing);
		float gap = P / count;
		float s = perim_param(p, a, b);
		idx = floor(s / gap + 0.5);
		c = perim_point(idx * gap, a, b);
	}
	float d = length(p - c);
	float on = step(fract((idx - TIME * chase) / group), 1.0 / group);
	float lit = mix(base_level, 1.0, on);
	lit *= step(idx / max(count, 1.0), intro);
	float core = smoothstep(radius, radius * 0.55, d);
	float halo = exp(-d * d / (radius * radius * 5.0)) * 0.55;
	vec3 col = mix(bulb_color.rgb * 0.55, vec3(1.0, 0.98, 0.9), core * lit);
	float alpha = max(core * (0.45 + 0.55 * lit), halo * lit);
	COLOR = vec4(col, alpha * bulb_color.a);
}
