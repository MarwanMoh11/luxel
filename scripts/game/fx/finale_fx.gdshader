shader_type canvas_item;
// The finale's own marks (P8, settings_fx.gd), on two full-screen rects:
// mode 0, CanvasLayer 3: the dark at the screen edges (above the world, under the HUD, the sold-look shader and the
//   top layer with the lantern and the eyes); the blast's ring blows it away inside `clear_r`.
// mode 1, CanvasLayer 7: the blast's shockwave ring and its flash (above the top layer, under the menu).
// Positions are game px across the whole screen, as in screen_fx.gdshader. Palette colours only, a hard 4x4
// ordered dither, no soft gradients.

uniform int mode = 0;
uniform vec2 view = vec2(320.0, 180.0); // game pixels across the screen
uniform vec4 void_colour : source_color = vec4(0.0510, 0.0431, 0.1176, 1.0); // 0d0b1e
uniform vec4 night_colour : source_color = vec4(0.1294, 0.1020, 0.2314, 1.0); // 211a3b
uniform vec4 cream_colour : source_color = vec4(1.0, 0.9569, 0.8627, 1.0); // fff4dc
uniform float edge = 0.0; // mode 0: the band's depth in px (0 = none)
uniform float clear_r = -1.0; // mode 0: < 0 off; else no band inside this radius around ring_pos
uniform float ring_r = -1.0; // mode 1: < 0 off; else the ring's outer radius around ring_pos
uniform vec2 ring_pos = vec2(160.0, 90.0); // the blast's centre (the lantern) in screen px
uniform float ring_width = 2.0; // px of cream at the ring's edge
uniform bool flash = false; // mode 1: the whole screen cream

const float DITHER = 6.0; // px at the band's inner line that dither out
const float RAG = 3.0; // px the inner line wanders, per 4 px segment along the edge
const float CORE = 0.45; // the outer part of the band (this share of it) is void, the rest night
const float BAYER[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

// Stable hash without sin() (as in screen_fx.gdshader).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bayer4(vec2 px) {
	int i = int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0));
	return (BAYER[i] + 0.5) / 16.0;
}

vec4 edge_band(vec2 px) {
	if (edge <= 0.0 || (clear_r >= 0.0 && length(px + 0.5 - ring_pos) < clear_r)) {
		return vec4(0.0);
	}
	vec2 far = view - 1.0 - px;
	float dx = min(px.x, far.x);
	float dy = min(px.y, far.y);
	// a ragged inner line: each 4 px segment along the nearest edge sits up to RAG px shallower
	float seg = dx < dy ? floor(px.y / 4.0) + (px.x < view.x * 0.5 ? 0.0 : 101.0)
			: floor(px.x / 4.0) + (px.y < view.y * 0.5 ? 211.0 : 307.0);
	float e = min(dx, dy) + floor(hash(vec2(seg, 7.0)) * (RAG + 1.0) * min(edge / 8.0, 1.0));
	float inner = edge - e; // px inside the band's inner line
	if (inner <= 0.0 || (inner < DITHER && inner / DITHER <= bayer4(px))) {
		return vec4(0.0);
	}
	return e < edge * CORE ? void_colour : night_colour;
}

vec4 blast(vec2 px) {
	if (flash) {
		return cream_colour;
	}
	if (ring_r >= 0.0) {
		float d = length(px + 0.5 - ring_pos);
		if (d < ring_r && d >= ring_r - ring_width) {
			return cream_colour;
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 px = floor(SCREEN_UV * view);
	COLOR = mode == 0 ? edge_band(px) : blast(px);
}
