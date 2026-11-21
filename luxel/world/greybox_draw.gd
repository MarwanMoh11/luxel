extends RefCounted
## Static Last Light 20-colour greybox tile renderer used by LxRegionLoader when no painted PNG exists.

const PAL: Dictionary = LxInteractable.PAL


static func draw_tile(c: CanvasItem, tx: int, ty: int, ts: float, ttype: String) -> void:
	var p := Vector2(float(tx) * ts, float(ty) * ts)
	var r := Rect2(p, Vector2(ts, ts))
	var h: int = (((tx * 374761393 + ty * 668265263) ^ ((tx * 1274126177) >> 4)) >> 7) & 255
	match ttype:
		"ground":
			c.draw_rect(r, PAL["teal"])
			if (h & 7) == 0:
				var sx: float = float(2 + ((h >> 3) % 9))
				var sy: float = float(3 + ((h >> 5) % 9))
				c.draw_rect(Rect2(p + Vector2(sx, sy), Vector2(4.0, 2.0)), PAL["pine"])
			elif (h % 12) == 3:
				var gx: float = float(2 + ((h >> 2) % 10))
				var gy: float = float(3 + ((h >> 4) % 9))
				c.draw_rect(Rect2(p + Vector2(gx, gy), Vector2(2.0, 2.0)), PAL["jade"])
				c.draw_rect(Rect2(p + Vector2(gx + 1.0, gy - 1.0), Vector2(1.0, 1.0)), PAL["jade"])
		"path":
			c.draw_rect(r, PAL["mauve"])
			if (h & 7) == 0:
				c.draw_rect(Rect2(p + Vector2(3.0, 6.0), Vector2(3.0, 2.0)), PAL["stone"])
		"wall":
			c.draw_rect(r, PAL["night"])
			c.draw_rect(Rect2(p + Vector2(1.0, 1.0), Vector2(ts - 2.0, ts - 5.0)), PAL["dusk"])
			c.draw_rect(Rect2(p + Vector2(1.0, 1.0), Vector2(ts - 2.0, 2.0)), PAL["mauve"])
		"water":
			c.draw_rect(r, PAL["blue"])
			if (h & 3) == 0:
				c.draw_rect(Rect2(p + Vector2(3.0, 6.0), Vector2(6.0, 1.0)), PAL["sky"])
		"pit":
			c.draw_rect(r, PAL["void"])
			c.draw_rect(Rect2(p, Vector2(ts, 2.0)), PAL["night"])
		"void":
			c.draw_rect(r, PAL["void"])
			if (h & 31) == 7:
				c.draw_rect(Rect2(p + Vector2(float(h % 12), float((h >> 3) % 12)), Vector2.ONE), PAL["ice"])
		"bramble":
			c.draw_rect(r, PAL["pine"])
			c.draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(ts - 4.0, ts - 4.0)), PAL["plum"])
			c.draw_line(p + Vector2(2.0, 2.0), r.end - Vector2(2.0, 2.0), PAL["jade"], 1.0)
			c.draw_line(p + Vector2(ts - 2.0, 2.0), p + Vector2(2.0, ts - 2.0), PAL["jade"], 1.0)
		"cracked":
			c.draw_rect(r, PAL["stone"])
			c.draw_line(p + Vector2(3.0, 2.0), p + Vector2(9.0, 10.0), PAL["dusk"], 1.0)
			c.draw_line(p + Vector2(9.0, 10.0), p + Vector2(13.0, 14.0), PAL["night"], 1.0)
		"tide":
			c.draw_rect(r, PAL["sky"])
			c.draw_rect(Rect2(p + Vector2(2.0, 4.0), Vector2(ts - 4.0, 2.0)), PAL["blue"])
			c.draw_rect(Rect2(p + Vector2(2.0, 10.0), Vector2(ts - 4.0, 2.0)), PAL["ice"])
		"phantom":
			c.draw_rect(r, PAL["void"])
			for yy: float in [1.0, ts - 2.0]:
				c.draw_line(p + Vector2(1.0, yy), p + Vector2(6.0, yy), PAL["ice"], 1.0)
				c.draw_line(p + Vector2(10.0, yy), p + Vector2(15.0, yy), PAL["ice"], 1.0)
		"bridge":
			c.draw_rect(r, PAL["wine"])
			c.draw_rect(Rect2(p, Vector2(ts, 2.0)), PAL["gold"])
			c.draw_rect(Rect2(p + Vector2(0.0, ts - 2.0), Vector2(ts, 2.0)), PAL["gold"])
			c.draw_line(p + Vector2(5.0, 2.0), p + Vector2(5.0, ts - 2.0), PAL["plum"], 1.0)
			c.draw_line(p + Vector2(11.0, 2.0), p + Vector2(11.0, ts - 2.0), PAL["plum"], 1.0)
		"glass", "mirror":
			c.draw_rect(r, PAL["sky"])
			c.draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(ts - 4.0, ts - 4.0)), PAL["ice"])
			c.draw_rect(r, PAL["gold"], false, 1.0)
		_:
			c.draw_rect(r, PAL["void"])
