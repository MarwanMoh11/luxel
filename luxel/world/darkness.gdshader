shader_type canvas_item;
// Smooth atmospheric twilight, biome-aware Last Light grading, vignette, and
// camera-prioritized warm lantern pools for Luxel 1.0 (GL Compatibility safe).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 cam_origin = vec2(0.0, 0.0);
uniform vec2 view_size = vec2(320.0, 180.0);
uniform float darkness_strength : hint_range(0.0, 1.0) = 0.56;
uniform float wave_radius = 0.0;
uniform vec2 wave_origin = vec2(640.0, 180.0);
uniform float wave_active = 0.0;

// Biome twilight shadow tint and subtle darkness-scaled corner vignette
uniform vec3 biome_tint = vec3(0.42, 0.40, 0.64);
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.14;
uniform float danger_pulse : hint_range(0.0, 1.0) = 0.0;

// Up to 16 camera-prioritized light pools: xy = world pos, z = radius (px), w = intensity (0..2)
uniform vec4 lights[16];
uniform int light_count = 0;

// Up to 8 feathered zone relight rectangles: xy = top-left world pos, zw = size (world px)
uniform vec4 lit_zones[8];
uniform float lit_zone_fade[8];
uniform int lit_zone_count = 0;

// Locked Last Light palette tint colours
uniform vec3 col_void = vec3(0.05098, 0.04314, 0.11765);   // #0d0b1e
uniform vec3 col_night = vec3(0.12941, 0.10196, 0.23137);  // #211a3b
uniform vec3 col_wine = vec3(0.32157, 0.14510, 0.26667);   // #522544
uniform vec3 col_gold = vec3(1.0, 0.85098, 0.54902);       // #ffd98c
uniform vec3 col_cream = vec3(1.0, 0.95686, 0.86275);      // #fff4dc

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	if (darkness_strength <= 0.001 && wave_active < 0.5 && danger_pulse <= 0.001) {
		COLOR = vec4(src, 1.0);
	} else {
		vec2 screen_px = UV * view_size;
		vec2 world_px = cam_origin + screen_px;

		// Softly feathered relit zones (wide 84 px smoothstep avoids hard rectangle edges)
		float lit = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= lit_zone_count) break;
			float f = lit_zone_fade[i];
			if (f <= 0.001) continue;
			vec4 r = lit_zones[i];
			vec2 dxy = max(max(r.xy - world_px, world_px - (r.xy + r.zw)), vec2(0.0));
			float edge_dist = length(dxy);
			float zone_l = (1.0 - smoothstep(0.0, 84.0, edge_dist)) * f;
			lit = max(lit, zone_l);
		}

		// Expanding dawn relight wave
		float wave_rim = 0.0;
		if (wave_active > 0.5) {
			float wd = distance(world_px, wave_origin);
			float inside = 1.0 - smoothstep(wave_radius - 16.0, wave_radius + 4.0, wd);
			lit = max(lit, inside);
			float rim_d = abs(wd - wave_radius);
			if (rim_d < 12.0) {
				wave_rim = 1.0 - smoothstep(0.0, 12.0, rim_d);
			}
		}

		// Smooth radial light pools (Wick lantern, thrown lantern, beacons, lamps, bursts)
		float warm_glow = 0.0;
		for (int i = 0; i < 16; i++) {
			if (i >= light_count) break;
			vec4 L = lights[i];
			if (L.z <= 1.0 || L.w <= 0.001) continue;
			float dist = distance(world_px, L.xy);
			if (dist >= L.z) continue;
			float n = 1.0 - dist / L.z;
			float smooth_n = n * n * (3.0 - 2.0 * n);
			float contrib = smooth_n * L.w;
			lit = max(lit, clamp(contrib * 1.35, 0.0, 1.0));
			float halo = smoothstep(0.0, 0.55, n) * (1.0 - smoothstep(0.55, 1.0, n));
			warm_glow = max(warm_glow, halo * min(L.w, 1.2) * 0.14);
		}

		float shadow_amt = clamp((1.0 - lit) * darkness_strength, 0.0, 1.0);
		vec3 out_col = src;

		if (shadow_amt > 0.002) {
			// Preserve bright emissive pixels (flames, eyes, golden tells) cleanly in darkness
			float luma = dot(src, vec3(0.299, 0.587, 0.114));
			float bright_guard = smoothstep(0.66, 0.88, luma);
			float eff = shadow_amt * (1.0 - bright_guard * 0.85);

			vec3 night_graded = src * biome_tint + col_night * 0.06;
			vec3 deep_tint = biome_tint * vec3(0.62, 0.60, 0.69);
			vec3 deep_graded = mix(src * deep_tint, col_void, 0.22);
			vec3 dark_col = mix(night_graded, deep_graded, smoothstep(0.45, 1.0, eff));
			out_col = mix(src, dark_col, eff);
		}

		// Warm candlelight transition bloom at pool rims in shadowed areas
		if (warm_glow > 0.003 && shadow_amt > 0.04) {
			out_col = mix(
				out_col,
				out_col * vec3(1.08, 1.03, 0.92) + col_gold * 0.09,
				warm_glow * min(shadow_amt * 2.2, 1.0)
			);
		}

		// Subtle corner vignette proportional to darkness_strength (vanishes cleanly at dawn)
		if (vignette_strength > 0.001 && darkness_strength > 0.001) {
			vec2 uv_c = (UV - vec2(0.5)) * vec2(1.0, 0.92);
			float edge_r = length(uv_c);
			float vig = smoothstep(0.42, 0.78, edge_r) * vignette_strength * darkness_strength;
			vig *= (1.0 - lit * 0.55);
			out_col = mix(out_col, col_void, clamp(vig, 0.0, 0.35));
		}

		// Smooth golden leading edge for the dawn relight wave
		if (wave_rim > 0.01) {
			vec3 rim_col = mix(col_gold, col_cream, smoothstep(0.45, 0.95, wave_rim));
			out_col = mix(out_col, rim_col, wave_rim * 0.55);
		}

		// Subtle Last Light wine edge heartbeat when Wick is on their last heart
		if (danger_pulse > 0.002) {
			vec2 duv = (UV - vec2(0.5)) * vec2(1.0, 0.92);
			float dvig = smoothstep(0.38, 0.76, length(duv)) * danger_pulse * 0.28;
			out_col = mix(out_col, col_wine, clamp(dvig, 0.0, 0.26));
		}

		COLOR = vec4(out_col, 1.0);
	}
}
