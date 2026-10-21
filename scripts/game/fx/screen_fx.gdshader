shader_type canvas_item;
// Low Settings: the sold GRAPHICS settings, applied to everything drawn below this layer (settings_fx.gd).
// Order: the flare's clean disc (design 10.3), sampling (resolution, vsync tear), then colours and brightness, then
// masks (view distance, dead pixels).
// All positions are in game pixels across the whole screen, so it works at any window scale. Staged finale
// transitions (design 10.2) blend from the *_prev values: resolution spreads in a circle from `center`, colours
// wipe down or up the screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 view = vec2(320.0, 180.0); // game pixels across the screen
uniform float block = 1.0; // RESOLUTION: 1, 2 or 4 px blocks
uniform float block_prev = 1.0; // the block size outside block_radius while it spreads
uniform float block_radius = -1.0; // < 0: block everywhere; else block inside this radius around center
uniform float tear = 0.0; // VSYNC off: 0..1 how far the rows above the tear line shift (eased in)
uniform float tear_y = -12.0; // the tear line's row (driven by settings_fx.gd so it drops in from the top)
uniform float tear_shift = 3.0; // px for this pass
uniform int colours = 0; // COLOURS: 0 = all 20, 1 = 4 colours, 2 = 2 colours
uniform int colours_prev = 0; // the colours on the side the wipe hasn't reached
uniform float wipe = 1.0; // 0..1 progress of the colours wipe (1 = done)
uniform bool wipe_down = true; // the wipe runs top to bottom (false: bottom to top)
uniform float brightness = 1.0; // BRIGHTNESS: 1 or 0.5 (one palette SHADE step; between them a dither)
uniform float glow_radius = 0.0; // the lantern's glow keeps full brightness inside this radius (px)
uniform vec2 glow_pos = vec2(160.0, 90.0); // lantern centre in screen px
uniform float fov_radius = 0.0; // VIEW DISTANCE (cut; kept): 0 = off, else the visible radius around center
uniform vec2 center = vec2(160.0, 90.0); // Wick in screen px
uniform float dead = 0.0; // PIXELS sold, 0..100 (eased by settings_fx.gd); 100 = all void
uniform float clear_radius = -1.0; // the flare (design 10.3): < 0 off; else inside this radius around glow_pos the
// screen passes through clean (only `dead` applies), with a 1 px ring_colour band at the radius
uniform vec4 ring_colour : source_color = vec4(1.0, 0.9569, 0.8627, 1.0);

const vec3 VOID = vec3(0.0510, 0.0431, 0.1176); // 0d0b1e
const vec3 MAUVE = vec3(0.5412, 0.4314, 0.5686); // 8a6e91
const vec3 APRICOT = vec3(0.9608, 0.6627, 0.4157); // f5a96a
const vec3 CREAM = vec3(1.0, 0.9569, 0.8627); // fff4dc
const float DEAD_BLOCK = 4.0;
// core.PAL (0-255) in core.py order and core.SHADE as indices (as in scripts/cast/shade.gdshader): BRIGHTNESS
// darkens every pixel one palette step, the way the map's own shadows do, so the screen stays palette-exact.
const vec3 PAL[20] = {
	vec3(13.0, 11.0, 30.0), vec3(33.0, 26.0, 59.0), vec3(61.0, 44.0, 92.0), vec3(106.0, 61.0, 111.0),
	vec3(160.0, 70.0, 106.0), vec3(226.0, 114.0, 91.0), vec3(245.0, 169.0, 106.0), vec3(255.0, 217.0, 140.0),
	vec3(255.0, 244.0, 220.0), vec3(29.0, 61.0, 76.0), vec3(43.0, 107.0, 104.0), vec3(76.0, 158.0, 120.0),
	vec3(163.0, 207.0, 125.0), vec3(38.0, 56.0, 115.0), vec3(62.0, 109.0, 176.0), vec3(120.0, 169.0, 218.0),
	vec3(199.0, 229.0, 239.0), vec3(138.0, 110.0, 145.0), vec3(194.0, 167.0, 174.0), vec3(236.0, 159.0, 168.0)
};
const int SHADE[20] = { 0, 0, 1, 2, 3, 4, 5, 6, 18, 1, 9, 10, 11, 1, 13, 14, 15, 2, 17, 4 };

// Stable hash without sin(), so every GPU (and WebGL) gives the same pattern.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// The palette colour nearest `c`, one SHADE step darker.
vec3 shade(vec3 c) {
	vec3 v = c * 255.0;
	int best = 0;
	float best_d = 1e9;
	for (int i = 0; i < 20; i++) {
		vec3 d = v - PAL[i];
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = i;
		}
	}
	return PAL[SHADE[best]] / 255.0;
}

// 2x2 ordered dither threshold for soft edges.
float bayer2(vec2 px) {
	vec2 m = mod(px, 2.0);
	if (m.y < 0.5) {
		return m.x < 0.5 ? 0.125 : 0.625;
	}
	return m.x < 0.5 ? 0.875 : 0.375;
}

vec2 sample_px(vec2 px) {
	vec2 p = px + 0.5;
	if (tear > 0.0 && p.y < tear_y) {
		p.x -= tear * tear_shift;
	}
	float b = block;
	if (block_radius >= 0.0 && length(px + 0.5 - center) > block_radius) {
		b = block_prev;
	}
	return floor(p / b) * b + b * 0.5;
}

vec3 reduce_colours(vec3 c, int n) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	if (n == 2) {
		return lum < 0.5 ? VOID : CREAM; // 0.5: the grass stays dark, the lights stay cream
	}
	if (lum < 0.25) {
		return VOID;
	}
	if (lum < 0.6) {
		return MAUVE;
	}
	return lum < 0.85 ? APRICOT : CREAM;
}

vec3 kill_pixels(vec3 c, vec2 px) {
	if (dead > 0.0) {
		// Each 4 px block dies at its own level 0..99 (scattered, stable) and fades in over one level.
		float dies_at = floor(hash(floor(px / DEAD_BLOCK) + vec2(17.0, 59.0)) * 100.0);
		float k = dead >= 100.0 ? 1.0 : clamp(dead - dies_at, 0.0, 1.0);
		c = mix(c, VOID, k);
	}
	return c;
}

void fragment() {
	vec2 px = floor(SCREEN_UV * view);
	float d = clear_radius >= 0.0 ? length(px + 0.5 - glow_pos) : -1.0;
	vec3 c;
	if (clear_radius >= 0.0 && d < clear_radius - 0.5) {
		c = texture(screen_tex, (px + 0.5) / view).rgb; // inside the flare's ring: clean, only the dead pixels apply
	} else if (clear_radius >= 0.0 && d < clear_radius + 0.5) {
		c = ring_colour.rgb;
	} else {
		c = texture(screen_tex, sample_px(px) / view).rgb;
		int n = colours;
		if (wipe < 1.0) {
			bool reached = wipe_down ? px.y < wipe * view.y : px.y >= (1.0 - wipe) * view.y;
			n = reached ? colours : colours_prev;
		}
		if (n > 0) {
			c = reduce_colours(c, n);
		}
		if (brightness < 1.0) {
			// 1 -> 0.5 dithers in one SHADE step; the lantern's glow (a dithered 3 px rim) stays lit
			bool lit = glow_radius > 0.0 && (length(px + 0.5 - glow_pos) - glow_radius) / 3.0 <= bayer2(px);
			if (!lit && (1.0 - brightness) * 2.0 > bayer2(px)) {
				c = shade(c);
			}
		}
		if (fov_radius > 0.0) {
			float edge = (length(px + 0.5 - center) - fov_radius) / 2.0;
			if (edge > bayer2(px)) {
				c = VOID;
			}
		}
	}
	COLOR = vec4(kill_pixels(c, px), 1.0);
}
