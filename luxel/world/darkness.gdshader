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
uniform float transition_fade : hint_range(0.0, 1.0) = 0.0;
uniform float dungeon_shafts : hint_range(0.0, 1.0) = 0.0;
uniform float shader_clock = 0.0;
uniform float phase_flash : hint_range(0.0, 1.0) = 0.0;
uniform float focus_flash : hint_range(0.0, 1.0) = 0.0;
uniform int biome_id = 1;
uniform float biome_phase : hint_range(0.0, 1.0) = 0.5;

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
uniform vec3 col_wine = vec3(0.62745, 0.27451, 0.41569);   // #a0466a
uniform vec3 col_coral = vec3(0.88627, 0.44706, 0.35686);  // #e2725b
uniform vec3 col_apricot = vec3(0.96078, 0.66275, 0.41569); // #f5a96a
uniform vec3 col_sky = vec3(0.47059, 0.66275, 0.85490);    // #78a9da
uniform vec3 col_gold = vec3(1.0, 0.85098, 0.54902);       // #ffd98c
uniform vec3 col_cream = vec3(1.0, 0.95686, 0.86275);      // #fff4dc

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	if (darkness_strength <= 0.001 && wave_active < 0.5 && danger_pulse <= 0.001 && transition_fade <= 0.001 && phase_flash <= 0.001 && focus_flash <= 0.001) {
		COLOR = vec4(src, 1.0);
	} else {
		vec2 screen_px = floor(UV * view_size) + vec2(0.5);
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

		// Radiant 3-band Last Light golden-apricot-cream dawn relight wave crest
		if (wave_rim > 0.01) {
			vec3 warm_band = mix(col_apricot, col_gold, smoothstep(0.18, 0.62, wave_rim));
			vec3 rim_col = mix(warm_band, col_cream, smoothstep(0.68, 0.94, wave_rim));
			float rim_a = clamp(wave_rim * 0.86, 0.0, 0.86);
			out_col = mix(out_col, rim_col, rim_a);
		}

		// Subtle Last Light wine edge heartbeat when Wick is on their last heart
		if (danger_pulse > 0.002) {
			vec2 duv = (UV - vec2(0.5)) * vec2(1.0, 0.92);
			float dvig = smoothstep(0.38, 0.76, length(duv)) * danger_pulse * 0.22;
			out_col = mix(out_col, col_wine, clamp(dvig, 0.0, 0.22));
		}

		// Subtle diagonal moonlight/skylight shafts across shadowed dungeon chambers
		if (dungeon_shafts > 0.01 && shadow_amt > 0.08) {
			float diag = (screen_px.x * 0.58 + screen_px.y * 0.82) / 56.0;
			float band = pow(max(0.0, sin(diag + shader_clock * 0.18)), 6.0);
			float vfade = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.62, 0.96, UV.y));
			float shaft_a = band * vfade * dungeon_shafts * shadow_amt * 0.13;
			out_col = mix(out_col, mix(out_col, col_sky, 0.45) + col_gold * 0.05, clamp(shaft_a, 0.0, 0.14));
		}

		// Distinct per-island atmospheric shader signature (coastal mist, forest canopy, lagoon caustics, kiln glow, lunar sheen, eclipse corona)
		if (biome_id == 2 && shadow_amt > 0.06) {
			float mist = pow(max(0.0, sin((screen_px.y * 0.08) + sin(screen_px.x * 0.03 + shader_clock * 0.7))), 4.0);
			out_col = mix(out_col, col_sky, mist * shadow_amt * (0.09 + 0.06 * biome_phase));
		} else if (biome_id == 3 && shadow_amt > 0.06) {
			float canopy = pow(max(0.0, sin((screen_px.x * 0.045 - screen_px.y * 0.03) + shader_clock * 0.25)), 5.0);
			out_col = mix(out_col, col_gold * 0.55 + col_sky * 0.35, canopy * shadow_amt * 0.09);
		} else if (biome_id == 4 && shadow_amt > 0.06) {
			float caust = pow(max(0.0, sin(screen_px.x * 0.09 + shader_clock * 1.1) * cos(screen_px.y * 0.09 - shader_clock * 0.8)), 3.0);
			out_col = mix(out_col, col_sky, caust * shadow_amt * 0.11);
		} else if (biome_id == 5 && shadow_amt > 0.06) {
			float grid_g = max(0.0, sin(screen_px.x * 0.11 + shader_clock * 0.2) * sin(screen_px.y * 0.11 - shader_clock * 0.2));
			out_col = mix(out_col, col_gold, pow(grid_g, 8.0) * shadow_amt * 0.14);
		} else if (biome_id == 6 && shadow_amt > 0.04) {
			float heat = smoothstep(0.55, 1.0, UV.y) * (0.65 + 0.35 * sin(shader_clock * 1.8 + biome_phase * 6.283));
			out_col = mix(out_col, col_coral, clamp(heat * shadow_amt * 0.22, 0.0, 0.20));
		} else if (biome_id == 7 && shadow_amt > 0.04) {
			out_col = mix(out_col, col_sky * 0.8 + col_cream * 0.2, biome_phase * shadow_amt * 0.14);
		} else if (biome_id == 8 && shadow_amt > 0.04) {
			float ec_r = length((UV - vec2(0.5)) * vec2(1.0, 0.92));
			float ec_ring = smoothstep(0.32, 0.72, ec_r) * biome_phase * 0.24;
			out_col = mix(out_col, col_wine * 0.65 + col_void * 0.35, clamp(ec_ring, 0.0, 0.22));
		}

		// Dramatic crimson-gold rim pulse on Boss Phase 2/3/4 escalations
		if (phase_flash > 0.002) {
			vec2 puv = (UV - vec2(0.5)) * vec2(1.0, 0.92);
			float pvig = smoothstep(0.28, 0.76, length(puv)) * phase_flash * 0.34;
			out_col = mix(out_col, mix(col_wine, col_coral, phase_flash * 0.65), clamp(pvig, 0.0, 0.32));
		}

		// Crisp golden rim focus shimmer on Perfect Dodge & Sunflare
		if (focus_flash > 0.002) {
			vec2 fuv = (UV - vec2(0.5)) * vec2(1.0, 0.92);
			float fvig = smoothstep(0.34, 0.78, length(fuv)) * focus_flash * 0.24;
			out_col = mix(out_col, col_gold, clamp(fvig, 0.0, 0.22));
		}

		// Velvety room/region arrival fade from Last Light void
		if (transition_fade > 0.002) {
			out_col = mix(out_col, col_void, clamp(transition_fade, 0.0, 1.0));
		}

		COLOR = vec4(out_col, 1.0);
	}
}
