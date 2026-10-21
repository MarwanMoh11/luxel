// Last Light shadows: wherever this canvas item draws (any colour), the ground under it turns one palette step
// darker (core.SHADE), so actor shadows match the map's baked ones on every zone. Expects a palette-exact screen.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// core.PAL (0-255), in core.py order: void night dusk plum wine coral apricot gold cream pine teal jade lime
// deep blue sky ice mauve stone rose.
const vec3 PAL[20] = {
	vec3(13.0, 11.0, 30.0), vec3(33.0, 26.0, 59.0), vec3(61.0, 44.0, 92.0), vec3(106.0, 61.0, 111.0),
	vec3(160.0, 70.0, 106.0), vec3(226.0, 114.0, 91.0), vec3(245.0, 169.0, 106.0), vec3(255.0, 217.0, 140.0),
	vec3(255.0, 244.0, 220.0), vec3(29.0, 61.0, 76.0), vec3(43.0, 107.0, 104.0), vec3(76.0, 158.0, 120.0),
	vec3(163.0, 207.0, 125.0), vec3(38.0, 56.0, 115.0), vec3(62.0, 109.0, 176.0), vec3(120.0, 169.0, 218.0),
	vec3(199.0, 229.0, 239.0), vec3(138.0, 110.0, 145.0), vec3(194.0, 167.0, 174.0), vec3(236.0, 159.0, 168.0)
};
// core.SHADE as indices into PAL.
const int SHADE[20] = { 0, 0, 1, 2, 3, 4, 5, 6, 18, 1, 9, 10, 11, 1, 13, 14, 15, 2, 17, 4 };

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	vec3 under = texture(screen_tex, SCREEN_UV).rgb * 255.0;
	int best = 0;
	float best_d = 1e9;
	for (int i = 0; i < 20; i++) {
		vec3 d = under - PAL[i];
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = i;
		}
	}
	COLOR = vec4(PAL[SHADE[best]] / 255.0, 1.0);
}
