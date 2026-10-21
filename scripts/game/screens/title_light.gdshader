// The title's light (scripts/game/screens/title.gd): the luxels light the grove. Drawn behind the title over the
// whole screen; every pixel is a palette colour or nothing, dithered on the 4x4 Bayer grid (ART_STYLE: glows are
// palette colours and ordered dither, never blended).
// Per luxel (x, y, reach, strength): light = sum of strength * (1 - d / reach); the dark (void) covers what the
// light misses, `dark` of the way. A halo of `halo_in` then `halo_out` rings each lit luxel
// (strength > 0), HALO px wide.
shader_type canvas_item;

const int MAX_LIGHTS = 64;
const float HALO = 6.0; // halo reach in px beyond the lamp's edge
const float BAYER[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

uniform vec4 lights[MAX_LIGHTS]; // title px: x, y, reach, strength (0 = out)
uniform int light_count = 0;
uniform float dark = 1.0; // 1 = the unlit screen is all void, 0 = no dark at all
uniform vec4 void_col : source_color;
uniform vec4 halo_in : source_color;
uniform vec4 halo_out : source_color;

varying vec2 px;

void vertex() {
	px = VERTEX; // the rect is drawn in the title's own px
}

void fragment() {
	vec2 p = floor(px) + 0.5;
	float light = 0.0;
	float halo = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float d = distance(p, l.xy);
		light += l.w * clamp(1.0 - d / max(l.z, 1.0), 0.0, 1.0);
		if (l.w > 0.0) {
			halo = max(halo, clamp(1.0 - (d - 2.0) / HALO, 0.0, 1.0));
		}
	}
	float b = (BAYER[(int(p.y) & 3) * 4 + (int(p.x) & 3)] + 0.5) / 16.0;
	if (halo > 0.55 + 0.4 * b) {
		COLOR = halo_in;
	} else if (halo > b) {
		COLOR = halo_out;
	} else if (dark * (1.0 - clamp(light, 0.0, 1.0)) > b) {
		COLOR = void_col;
	} else {
		discard;
	}
}
