class_name LxBeaconRituals
extends RefCounted
## Renders distinct per-island ritual mechanisms on Beacons (Islands 1..8) and triggers
## unique live biome world payoffs on ignition — strictly using the 20 Last Light colours.

const PAL: Dictionary = LxPalette.PAL


static func draw_biome_crown(canvas: CanvasItem, island_id: int, lit: bool, ignitable: bool, clock: float, ignite_t: float) -> void:
	if not lit and not ignitable:
		return
	var fred: bool = LxHudFx.flash_reduced()
	var pulse: float = 0.0 if fred else sin(clock * 3.4)
	match island_id:
		2: # Tidewater Harbor: Brass Sea-Bell Fog-Horn Buoy + oceanic sonar rings
			var col: Color = (PAL["ice"] if lit else PAL["sky"]) as Color
			canvas.draw_arc(Vector2(0.0, -16.0), 8.0 + pulse * 1.2, PI * 1.15, PI * 1.85, 10, col, 1.4)
			if lit:
				var r_wave: float = roundf(10.0 + fposmod(clock * 14.0, 18.0))
				var a_wave: float = clampf(1.0 - (r_wave - 10.0) / 18.0, 0.0, 1.0) * 0.72
				canvas.draw_arc(Vector2(0.0, -14.0), r_wave, 0.0, TAU, 18, Color(PAL["sky"] as Color, a_wave), 1.2)
		3: # Thornwood Hollow: Living Heartwood Sap-Shrine w/ swirling emerald canopy petals
			for k: int in range(4):
				var a: float = clock * (1.8 if lit else 0.9) + float(k) * (TAU / 4.0)
				var pt := Vector2(roundf(cos(a) * (11.0 if lit else 8.0)), roundf(-14.0 + sin(a) * 5.0))
				canvas.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), (PAL["lime"] if lit else PAL["jade"]) as Color)
			if lit:
				canvas.draw_arc(Vector2(0.0, -14.0), 12.0 + pulse, 0.0, TAU, 16, Color(PAL["jade"] as Color, 0.65), 1.0)
		4: # Mirefen Gardens: Sunken Glasshouse Hydro-Fountain plume
			if lit:
				for k: int in range(5):
					var u: float = fposmod(clock * 1.6 + float(k) * 0.2, 1.0)
					var fx: float = roundf(sin(float(k) * 1.8 + clock * 2.0) * (3.0 + u * 8.0))
					var fy: float = roundf(-14.0 - sin(u * PI) * 16.0)
					canvas.draw_rect(Rect2(fx, fy, 2.0, 2.0), (PAL["ice"] if u < 0.45 else PAL["sky"]) as Color)
				canvas.draw_arc(Vector2(0.0, -8.0), 13.0 + pulse, 0.0, TAU, 16, Color(PAL["rose"] as Color, 0.55), 1.0)
		5: # Starfall Observatory: Counter-spinning golden Astrolabe Relay + skyward starlight beam
			var r1: float = 11.0 if lit else 8.0
			var rot: float = clock * (2.4 if lit else 1.1)
			canvas.draw_arc(Vector2(0.0, -15.0), r1, rot, rot + 2.4, 12, PAL["gold"] as Color, 1.2)
			canvas.draw_arc(Vector2(0.0, -15.0), r1, rot + PI, rot + PI + 2.4, 12, PAL["sky"] as Color, 1.2)
			if lit:
				canvas.draw_line(Vector2(0.0, -18.0), Vector2(0.0, -68.0), Color(PAL["ice"] as Color, 0.55), 2.0)
				canvas.draw_line(Vector2(0.0, -18.0), Vector2(0.0, -68.0), Color(PAL["cream"] as Color, 0.85), 1.0)
		6: # Ashen Kiln: Volcanic Smelter Crucible twin flame-jets
			if lit:
				for side: float in [-1.0, 1.0]:
					var h_jet: float = roundf(12.0 + (0.0 if fred else absf(sin(clock * 8.0 + side)) * 6.0))
					canvas.draw_rect(Rect2(side * 8.0 - 1.0, -12.0 - h_jet, 2.0, h_jet), PAL["coral"] as Color)
					canvas.draw_rect(Rect2(side * 8.0, -12.0 - h_jet * 0.65, 1.0, h_jet * 0.65), PAL["gold"] as Color)
		7: # Moon Shoals: Twin Lunar Mirror Obelisk + inverted reflection shaft
			var col_m: Color = (PAL["cream"] if lit else PAL["ice"]) as Color
			canvas.draw_arc(Vector2(0.0, -20.0), 6.0, -PI * 0.6, PI * 0.6, 10, col_m, 1.5)
			if lit:
				canvas.draw_line(Vector2(0.0, 4.0), Vector2(0.0, 26.0), Color(PAL["sky"] as Color, 0.55), 3.0)
				canvas.draw_line(Vector2(0.0, 4.0), Vector2(0.0, 24.0), Color(PAL["ice"] as Color, 0.85), 1.0)
		8: # The Long Night: Fractured Eclipse Seal Altar -> Golden Dawn Pillar
			if lit:
				canvas.draw_line(Vector2(0.0, -16.0), Vector2(0.0, -78.0), Color(PAL["gold"] as Color, 0.62), 3.0)
				canvas.draw_line(Vector2(0.0, -16.0), Vector2(0.0, -78.0), Color(PAL["cream"] as Color, 0.90), 1.0)
				canvas.draw_arc(Vector2(0.0, -18.0), 11.0 + pulse, 0.0, TAU, 16, PAL["gold"] as Color, 1.4)
			else:
				canvas.draw_arc(Vector2(0.0, -16.0), 9.0, 0.0, TAU, 14, PAL["plum"] as Color, 1.4)
				canvas.draw_arc(Vector2(0.0, -16.0), 9.0, -0.5, 0.9, 8, PAL["rose"] as Color, 1.2)

	# Extra celebratory burst ring during ignition tailored to each biome's signature palette
	if ignite_t > 0.0 and lit:
		var u: float = 1.0 - clampf(ignite_t / 0.56, 0.0, 1.0)
		var bc: Color = _biome_accent(island_id)
		canvas.draw_arc(Vector2(0.0, -12.0), roundf(lerpf(10.0, 52.0, u)), 0.0, TAU, 24, Color(bc, (1.0 - u) * 0.9), 2.0)


static func on_beacon_ignited(beacon: LxBeacon) -> void:
	if beacon == null:
		return
	var isl: int = beacon.island_id
	var pos: Vector2 = beacon.pos
	var br: LxBiomeRules = LxBiomeRules.active_instance
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	match isl:
		1: # Bell Isle: warm bell-harmonic ripple auto-ignites nearby unlit road lamps (domino wave!)
			if beacon.region != null and beacon.region.has_method("get_interactables"):
				var items_v: Variant = beacon.region.call("get_interactables")
				if items_v is Array:
					for it: Variant in (items_v as Array):
						if it is LxRoadLamp and is_instance_valid(it):
							var rl: LxRoadLamp = it as LxRoadLamp
							if rl.active and not rl.lit and rl.pos.distance_to(pos) <= 220.0:
								rl.interact(null)
		2: # Harbor Fog-Horn calms the coastal tide surge & washes ashore 2 bonus Drift-Shards!
			if br != null and is_instance_valid(br):
				br.tide_phase = 0.0
				br.tide_surging = false
			if bm != null and is_instance_valid(bm):
				bm.spawn_drift_shards_near(pos, 2)
			if Lx.audio != null:
				Lx.audio.play_sfx("lighthouse_toll", pos, true)
		3: # Ancient Sap-Shrine triggers a massive emerald canopy chain wave + heals +0.5 heart of forest dew!
			if bm != null and is_instance_valid(bm):
				bm.on_bloom_ignited(pos, true)
			if Lx.state != null and Lx.state.hearts < float(Lx.state.max_hearts):
				Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 0.5)
				if Lx.events != null:
					Lx.events.player_healed.emit(0.5)
		4: # Glasshouse Hydro-Fountain spawns a permanent live Mist Updraft & grants 3.5s Rose Tailwind!
			if bm != null and is_instance_valid(bm):
				bm.add_permanent_updraft(pos + Vector2(0.0, 26.0))
				bm.tailwind_t = maxf(bm.tailwind_t, 3.5)
			if Lx.audio != null:
				Lx.audio.play_sfx("wing_gale", pos, true)
		5: # Celestial Astrolabe Relay grants 4s Starlight Surge & links Constellation Ley-Lines!
			if br != null and is_instance_valid(br):
				br.starlight_surge_t = maxf(br.starlight_surge_t, 4.0)
			if Lx.audio != null:
				Lx.audio.play_sfx("prism_chain", pos, true)
		6: # Volcanic Smelter Crucible fills Ember + grants 3 Molten Overdrive charges + seismic knockback!
			if bm != null and is_instance_valid(bm):
				bm.grant_molten_overdrive(3)
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				var w: LxWick = Lx.player as LxWick
				if w.move_sunflare != null and w.move_sunflare.unlocked:
					w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 25.0)
			if beacon.region != null and beacon.region.has_method("get_enemies"):
				var ev: Variant = beacon.region.call("get_enemies")
				if ev is Array:
					for e_v: Variant in (ev as Array):
						if e_v is LxEnemyBrain and is_instance_valid(e_v):
							var e: LxEnemyBrain = e_v as LxEnemyBrain
							if e.is_alive() and not e.is_boss and e.pos.distance_to(pos) <= 140.0:
								e.knock += (e.pos - pos).normalized() * 110.0
			if Lx.audio != null:
				Lx.audio.play_sfx("forge_gust", pos, true)
		7: # Lunar Mirror Obelisk aligns Moon toward radiant Full Silver Moon & links silver ley-lines!
			if br != null and is_instance_valid(br):
				br.lunar_phase = 1.0
				br.clock = 0.0
			if Lx.audio != null:
				Lx.audio.play_sfx("prop_chime", pos, true)
		8: # Eclipse Seal Altar shatters one sky seal
			if Lx.audio != null:
				Lx.audio.play_sfx("bell_toll", pos, false)


static func _biome_accent(island_id: int) -> Color:
	match island_id:
		2:
			return PAL["sky"] as Color
		3:
			return PAL["lime"] as Color
		4:
			return PAL["ice"] as Color
		5:
			return PAL["gold"] as Color
		6:
			return PAL["coral"] as Color
		7:
			return PAL["ice"] as Color
		8:
			return PAL["rose"] as Color
		_:
			return PAL["gold"] as Color
