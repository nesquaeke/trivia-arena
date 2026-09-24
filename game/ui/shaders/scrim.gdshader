shader_type canvas_item;
// Menülerin arkasındaki yumuşak karartma: bir kenardan içeri doğru söner.
uniform vec4 tint : source_color = vec4(0.05, 0.02, 0.03, 1.0);
uniform float strength = 0.9;
uniform float reach = 0.6;         // kontrol genişliğinin ne kadarı
uniform vec2 dir = vec2(1.0, 0.0); // (1,0): soldan sağa söner; (0,1): yukarıdan aşağı
uniform float breathe = 0.04;
void fragment() {
	float x = dot(UV, dir) + (dir.x < 0.0 || dir.y < 0.0 ? 1.0 : 0.0);
	float a = strength * (1.0 - smoothstep(0.0, reach, x));
	a *= 1.0 - breathe * (0.5 + 0.5 * sin(TIME * 0.7));
	COLOR = vec4(tint.rgb, a * COLOR.a);
}
