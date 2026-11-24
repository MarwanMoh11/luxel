shader_type canvas_item;

// Island 8 ("THE LANTERN ASKS") world-layer post-FX shader (GL Compatibility safe).
// Renders on CanvasLayer 7 (above world & DarknessLayer 5, below LxUiRoot 10 & TollMenu 15).
// Implements:
//  - palette_4: 20-colour -> 4-colour Dusk collapse (void, dusk, apricot, cream)
//    with smooth 0.6s ordered-dither wipe under Flash Reduction.
//  - fps_step: visual frame-hold texture (24 fps / 30 fps reduced) + faint 1-frame ghost.
//  - display_pixels: dead 4 px void blocks (0..100%), Bayer edge-inward dither under reduced mode.
//  - dawn_clear: circular expansion restoring full colour & pixels from the Great Lamp.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D hold_tex : filter_nearest;
uniform sampler2D ghost_tex : filter_nearest;

uniform vec2 view_size = vec2(320.0, 180.0);
uniform float palette_4_mix = 0.0;
uniform float palette_wipe_y = 1.0;
uniform float pixels_loss = 0.0;
uniform bool reduced_mode = false;
uniform bool hold_active = false;
uniform bool ghost_active = false;
uniform float ghost_alpha = 0.0;
uniform vec2 clear_center_uv = vec2(0.5, 0.5);
uniform float clear_radius_px = 0.0;

const vec3 C_VOID    = vec3(0.05098, 0.04314, 0.11765); // #0d0b1e
const vec3 C_DUSK    = vec3(0.23922, 0.17255, 0.36078); // #3d2c5c
const vec3 C_APRICOT = vec3(0.96078, 0.66275, 0.41569); // #f5a96a
const vec3 C_CREAM   = vec3(1.00000, 0.95686, 0.86275); // #fff4dc

float bayer4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int idx = y * 4 + x;
	if (idx == 0) return 0.0 / 16.0;
	if (idx == 1) return 8.0 / 16.0;
	if (idx == 2) return 2.0 / 16.0;
	if (idx == 3) return 10.0 / 16.0;
	if (idx == 4) return 12.0 / 16.0;
	if (idx == 5) return 4.0 / 16.0;
	if (idx == 6) return 14.0 / 16.0;
	if (idx == 7) return 6.0 / 16.0;
	if (idx == 8) return 3.0 / 16.0;
	if (idx == 9) return 11.0 / 16.0;
	if (idx == 10) return 1.0 / 16.0;
	if (idx == 11) return 9.0 / 16.0;
	if (idx == 12) return 15.0 / 16.0;
	if (idx == 13) return 7.0 / 16.0;
	if (idx == 14) return 13.0 / 16.0;
	return 5.0 / 16.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 quantize_palette_4(vec3 col, vec2 px) {
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float d = (bayer4(px) - 0.5) * 0.08;
	float v = clamp(luma + d, 0.0, 1.0);
	if (v < 0.21) {
		return C_VOID;
	} else if (v < 0.48) {
		return C_DUSK;
	} else if (v < 0.78) {
		return C_APRICOT;
	}
	return C_CREAM;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = floor(uv * view_size);
	vec3 col = hold_active ? texture(hold_tex, uv).rgb : texture(screen_tex, uv).rgb;

	if (hold_active && ghost_active && ghost_alpha > 0.005) {
		vec3 gcol = texture(ghost_tex, uv).rgb;
		float diff = length(col - gcol);
		if (diff > 0.10) {
			col = mix(col, gcol, ghost_alpha);
		}
	}

	float dist_clear = length((uv - clear_center_uv) * view_size);
	bool in_clear = clear_radius_px > 0.5 && dist_clear < clear_radius_px;

	if (!in_clear && palette_4_mix > 0.001) {
		bool apply_p4 = true;
		if (reduced_mode && palette_wipe_y < 0.999) {
			float edge = palette_wipe_y + (bayer4(px) - 0.5) * 0.08;
			apply_p4 = uv.y <= edge;
		} else if (palette_wipe_y < 0.999) {
			apply_p4 = uv.y <= palette_wipe_y;
		}
		if (apply_p4) {
			vec3 q = quantize_palette_4(col, px);
			col = mix(col, q, palette_4_mix);
		}
	}

	if (!in_clear && pixels_loss > 0.001) {
		vec2 cell = floor(px / 4.0);
		vec2 grid_n = floor(view_size / 4.0);
		vec2 edge_d = min(cell, max(vec2(1.0), grid_n - vec2(1.0) - cell)) / max(vec2(1.0), grid_n * 0.5);
		float border_bias = 1.0 - clamp(min(edge_d.x, edge_d.y), 0.0, 1.0);
		float n = reduced_mode
			? clamp(bayer4(cell) * 0.65 + (1.0 - border_bias) * 0.35, 0.0, 1.0)
			: clamp(hash21(cell) * 0.72 + (1.0 - border_bias) * 0.28, 0.0, 1.0);
		// Keep a tiny central sanctuary around Wick readable until pixels_loss approaches 1.0
		float center_d = length((uv - vec2(0.5, 0.5)) * vec2(1.6, 1.0));
		if (pixels_loss >= 0.99 || (n < pixels_loss && center_d > (1.0 - pixels_loss) * 0.36)) {
			col = C_VOID;
		}
	}

	COLOR = vec4(col, 1.0);
}
