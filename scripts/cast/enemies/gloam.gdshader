// The Gloam's reveal (scripts/cast/enemies/gloam.gd; rule in art/cast/enemies/gloam/gloam.json "reveal"): a body
// pixel draws only where the light reaches it, dithered in on the world's 4x4 Bayer grid (core.bayer), so the
// dither stays put on the map while the Gloam moves through it.
// Per light (x, y, radius, full): r = clamp((radius - d) / (radius - full), 0, 1), d = distance from the pixel's
// centre; reveal = max over the lights. The draw call's modulate red channel says what is drawn:
//   1   = body (and its flash-free frames): draws where reveal > bayer
//   0.5 = specks: only inside a light (reveal > 0), where reveal + 0.3 > bayer (the stars lead the dark)
//   0   = eyes, death stars and the hit flash: always
// The modulate is reset to white, so the sheets' palette colours come out exact.
shader_type canvas_item;

const int MAX_LIGHTS = 8;
const float SPECK_LEAD = 0.3;
const float BAYER[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

uniform vec4 lights[MAX_LIGHTS]; // world px: x, y, radius, fully revealed inside this
uniform int light_count = 0;

varying vec2 world;
varying float mode;

void vertex() {
	world = VERTEX; // the draw calls are in world px (the game sets the node's draw transform)
	mode = COLOR.r;
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}

void fragment() {
	if (mode > 0.25) {
		vec2 px = floor(world);
		float reveal = 0.0;
		for (int i = 0; i < light_count; i++) {
			vec4 l = lights[i];
			reveal = max(reveal, clamp((l.z - distance(px + 0.5, l.xy)) / (l.z - l.w), 0.0, 1.0));
		}
		if (mode < 0.75) {
			if (reveal <= 0.0) {
				discard;
			}
			reveal += SPECK_LEAD;
		}
		int bx = int(px.x) & 3;
		int by = int(px.y) & 3;
		if (reveal <= (BAYER[by * 4 + bx] + 0.5) / 16.0) {
			discard;
		}
	}
}
