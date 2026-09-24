shader_type canvas_item;
// Pirinç/altın yüzeylerde çapraz kayan parıltı. Çizilen her şeye (yazı dahil) uygulanır.
// size: kontrolün piksel boyutu (kod her karede günceller)
uniform vec2 size = vec2(400.0, 80.0);
uniform float period = 3.2;      // iki parıltı arası saniye
uniform float width = 0.12;      // bant genişliği (0-1)
uniform float strength = 0.55;
uniform float hover = 0.0;       // 0-1: fare üstündeyken sürekli parlaklık
uniform float offset = 0.0;      // birden çok düğme aynı anda parlamasın
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 uv = lp / max(size, vec2(1.0));
	float t = fract((TIME + offset) / period) * 2.6 - 0.8;
	float d = (uv.x + (uv.y - 0.5) * 0.45) - t;
	float band = exp(-(d * d) / (width * width));
	float glow = band * strength + hover * 0.12;
	COLOR.rgb = COLOR.rgb + COLOR.rgb * glow + vec3(glow * 0.25);
}
