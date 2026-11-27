class_name LxPipStoryFx
extends RefCounted
## One-shot storybook island/milestone chirp reactions, Dawn Ending Pip cameo beside
## Wick's lantern, and Results Screen Pip Nectar/Charms badge.
## Strictly 20 Last Light colours (LxPalette.PAL) and integer pixel-snapped drawing.

const REGION_REACTIONS: Dictionary = {
	"0:overworld": "PIP_REACT_HUB",
	"2:overworld": "PIP_REACT_I2",
	"3:overworld": "PIP_REACT_I3",
	"4:overworld": "PIP_REACT_I4",
	"5:overworld": "PIP_REACT_I5",
	"6:overworld": "PIP_REACT_I6",
	"7:overworld": "PIP_REACT_I7",
	"8:overworld": "PIP_REACT_I8",
	"8:sanctum_r6": "PIP_REACT_HUSH",
}


static func on_region_entered(island_id: int, region_id: String) -> bool:
	if Lx.state == null or not LxFireflyState.is_joined() or LxHudFx.is_ceremony_active():
		return false
	var rk: String = "%d:%s" % [island_id, region_id]
	if not REGION_REACTIONS.has(rk):
		return false
	var key: String = str(REGION_REACTIONS[rk])
	var flag: String = "pip_react:" + key
	if bool(Lx.state.story_flags.get(flag, false)):
		return false
	Lx.state.story_flags[flag] = true
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_chirp", Vector2.ZERO, false)
		Lx.events.narration_requested.emit(key, "narration", 2.8)
	return true


static func draw_ending_pip(ci: CanvasItem, t: float) -> void:
	if Lx.state != null and not LxFireflyState.is_joined():
		return
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var tint: Dictionary = LxFireflyState.get_tint_colors()
	var c_core: Color = tint["core"] as Color
	var c_glow: Color = tint["glow"] as Color
	var c_wing: Color = tint["wing"] as Color
	var c_rim: Color = tint["rim"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var hx: float = 34.0 if fred else roundf(34.0 + cos(t * 1.9) * 2.0)
	var hy: float = 137.0 if fred else roundf(137.0 + sin(t * 3.1) * 1.6)
	var c := Vector2(hx, hy)
	var flap: float = 0.0 if fred else (1.0 if (int(floorf(t * 14.0)) % 2 == 0) else -1.0)

	# Void outline behind wings & glowing abdomen
	ci.draw_rect(Rect2(c + Vector2(-4.0, -3.0 + flap), Vector2(3.0, 3.0)), void_c)
	ci.draw_rect(Rect2(c + Vector2(1.0, -3.0 - flap), Vector2(3.0, 3.0)), void_c)
	ci.draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(5.0, 6.0)), void_c)
	# Flapping wings
	ci.draw_rect(Rect2(c + Vector2(-3.0, -2.0 + flap), Vector2(2.0, 1.0)), c_wing)
	ci.draw_rect(Rect2(c + Vector2(2.0, -2.0 - flap), Vector2(2.0, 1.0)), c_wing)
	# Glowing body
	ci.draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(3.0, 2.0)), c_rim)
	ci.draw_rect(Rect2(c + Vector2(-1.0, 1.0), Vector2(3.0, 2.0)), c_glow)
	ci.draw_rect(Rect2(c + Vector2(0.0, 1.0), Vector2(1.0, 2.0)), c_core)
	# Golden crown at Bond Rank 3+
	if LxFireflyState.get_bond_rank() >= 3:
		ci.draw_rect(Rect2(c + Vector2(-1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
		ci.draw_rect(Rect2(c + Vector2(1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
		if LxFireflyState.get_charm_count() >= 4:
			ci.draw_rect(Rect2(c + Vector2(0.0, -4.0), Vector2(1.0, 1.0)), pal["cream"] as Color)
	# 2 tiny trailing pollen motes rising toward the dawn
	for i: int in range(2):
		var u: float = (0.35 + float(i) * 0.35) if fred else fmod(t * 0.55 + float(i) * 0.5, 1.0)
		var mx: float = roundf(c.x + 2.0 + u * 8.0 + (0.0 if fred else sin(t * 2.2 + float(i) * 2.4) * 1.5))
		var my: float = roundf(c.y - 3.0 - u * 12.0)
		ci.draw_rect(Rect2(mx, my, 1.0, 1.0), c_core if u < 0.35 else (c_glow if i == 0 else (pal["gold"] as Color)))


static func draw_results_pip_badge(ci: CanvasItem, panel: Rect2, t: float) -> void:
	if Lx.state != null and not LxFireflyState.is_joined():
		return
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var tint: Dictionary = LxFireflyState.get_tint_colors()
	var c_core: Color = tint["core"] as Color
	var c_glow: Color = tint["glow"] as Color
	var c_rim: Color = tint["rim"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var nectar: int = LxFireflyState.get_nectar_count()
	var charms: int = LxFireflyState.get_charm_count()
	var txt: String = LxFolkData.fmt_id("PIP_RESULTS_FMT", [nectar, charms])
	var tw: int = LxPixelFont.width(txt, 1)
	var pw: float = float(tw) + 12.0
	var ph: float = 9.0
	var bx: float = roundf(panel.end.x - 6.0 - pw)
	var by: float = roundf(panel.position.y + 14.0)

	# Crisp pixel-snapped pill frame
	ci.draw_rect(Rect2(bx - 1.0, by - 1.0, pw + 2.0, ph + 2.0), void_c)
	ci.draw_rect(Rect2(bx, by, pw, ph), pal["night"] as Color)
	ci.draw_rect(Rect2(bx, by, pw, 1.0), c_rim)
	ci.draw_rect(Rect2(bx, by + ph - 1.0, pw, 1.0), pal["dusk"] as Color)

	# Tiny 3x3 Pip glow dot on the left
	var pulse: bool = fred or (int(floorf(t * 3.5)) % 2 == 0)
	ci.draw_rect(Rect2(bx + 2.0, by + 2.0, 5.0, 5.0), void_c)
	ci.draw_rect(Rect2(bx + 3.0, by + 3.0, 3.0, 3.0), c_glow)
	ci.draw_rect(Rect2(bx + 4.0, by + 4.0, 1.0, 1.0), c_core if pulse else (pal["gold"] as Color))

	# Compact Nectar & Charms summary text
	LxPixelFont.draw_left(ci, txt, Vector2(bx + 9.0, by + 2.0), pal["cream"] as Color, 1, void_c)
