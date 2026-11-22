class_name LxRestShop
extends Node2D
## Lamplighter's Rest upgrade shrine reading luxel/data/upgrades.json (SWARM_SPEC 3.5).

signal closed()
signal upgrade_bought(upgrade_id: String, new_rank: int)

const PANEL_RECT := Rect2(20.0, 12.0, 280.0, 156.0)
const SPARK_DUR: float = 0.45

const ICON_PAL: Dictionary = {
	"k": "void", "n": "night", "d": "dusk", "m": "mauve",
	"w": "wine", "r": "coral", "a": "apricot", "g": "gold",
	"c": "cream", "b": "blue", "s": "sky", "i": "ice",
}

const UPGRADE_ICONS: Dictionary = {
	"bolt_damage": ["...c...", "..cgc..", "..gag..", ".gacag.", ".argrr.", "..dgd..", "..nnn.."],
	"bolt_rate": ["...cg..", "..cga..", ".cgag..", "..agac.", ".s.gag.", "..cga..", ".s.a..."],
	"throw_damage": ["..aga..", ".dgggd.", ".a.c.a.", ".acgca.", ".a.g.a.", ".dgggd.", "..ddd.."],
	"dash_cooldown": [".g...g.", "gg.c.gg", "agacaga", ".a.c.a.", ".s.g.s.", "..s.s..", "...a..."],
	"ember_meter": [".rr.rr.", "ragagar", "ragcgar", "raggagr", ".rgggr.", "..rar..", "...w..."],
	"prism_bounce": ["...g...", "..iic..", ".iissc.", ".iissb.", "gisbbbg", ".gbbbg.", "..ddd.."],
}
const DEFAULT_ICON: Array[String] = ["...g...", "..gag..", ".gacag.", "..gag..", "...g...", ".......", "......."]

var _upgrades: Array[Dictionary] = []
var _idx: int = 0
var _close_hover: bool = false
var _feedback_key: String = ""
var _feedback_col: String = "lime"
var _feedback_t: float = 0.0
var _elapsed: float = 0.0
var _spark_row: int = -1
var _spark_pip: int = -1
var _spark_t: float = 0.0
var _deny_row: int = -1
var _deny_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_load_upgrades()
	_idx = 0
	_feedback_key = ""
	_feedback_t = 0.0
	_elapsed = 0.0
	_spark_row = -1
	_spark_pip = -1
	_spark_t = 0.0
	_deny_row = -1
	_deny_t = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _load_upgrades() -> void:
	_upgrades.clear()
	if Lx.data_upgrades.is_empty():
		Lx.load_all_data()
	var arr: Variant = Lx.data_upgrades.get("upgrades", [])
	if arr is Array:
		for item: Variant in (arr as Array):
			if item is Dictionary:
				_upgrades.append(item as Dictionary)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - delta)
		if _feedback_t <= 0.0:
			_feedback_key = ""
	if _spark_t > 0.0:
		_spark_t = maxf(0.0, _spark_t - delta)
		if _spark_t <= 0.0:
			_spark_row = -1
			_spark_pip = -1
	if _deny_t > 0.0:
		_deny_t = maxf(0.0, _deny_t - delta)
		if _deny_t <= 0.0:
			_deny_row = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var over_close: bool = _close_btn_rect().has_point(pos)
		if over_close != _close_hover:
			_close_hover = over_close
			if over_close:
				_play_ui_sfx("ui_move")
			queue_redraw()
		for i: int in range(_upgrades.size()):
			if _row_rect(i).has_point(pos):
				if _idx != i:
					_idx = i
					_play_ui_sfx("ui_move")
					queue_redraw()
				return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _close_btn_rect().has_point(mb.position):
				_play_ui_sfx("ui_back")
				closed.emit()
				get_viewport().set_input_as_handled()
				return
			for i: int in range(_upgrades.size()):
				if _row_rect(i).has_point(mb.position):
					_idx = i
					_try_buy(_idx)
					get_viewport().set_input_as_handled()
					return
		return

	var count: int = maxi(1, _upgrades.size())
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + count) % count
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % count
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_try_buy(_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("ui_back")
		closed.emit()
		get_viewport().set_input_as_handled()


func _try_buy(i: int) -> void:
	if i < 0 or i >= _upgrades.size() or Lx.state == null:
		return
	var u: Dictionary = _upgrades[i]
	var uid: String = str(u.get("id", ""))
	if Lx.state.buy_upgrade(uid):
		var new_rank: int = Lx.state.get_upgrade_rank(uid)
		_feedback_key = "SHOP_BOUGHT"
		_feedback_col = "lime"
		_feedback_t = 1.6
		_spark_row = i
		_spark_pip = maxi(0, new_rank - 1)
		_spark_t = SPARK_DUR
		_play_ui_sfx("shop_buy")
		if Lx.events != null:
			Lx.events.save_requested.emit("upgrade")
		upgrade_bought.emit(uid, new_rank)
	else:
		_feedback_key = "SHOP_MAXED" if Lx.state.get_upgrade_rank(uid) >= int(u.get("max_rank", 0)) else "SHOP_NO_SHARDS"
		_feedback_col = "stone" if _feedback_key == "SHOP_MAXED" else "coral"
		_feedback_t = 1.2
		_deny_row = i
		_deny_t = 0.22
		_play_ui_sfx("denied")
	queue_redraw()


func _draw() -> void:
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", "gold", "night")
	_draw_frame_ornaments()
	_draw_brazier_icon(Vector2(27.0, 16.0))
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_TITLE"), Vector2(38.0, 18.0), LxPalette.PAL["gold"], 1)
	var shards: int = Lx.state.shards if Lx.state != null else 0
	var shard_txt: String = LxStrings.fmt("SHOP_SHARDS_FMT", [shards])
	var gem_x: float = 292.0 - float(LxPixelFont.width(shard_txt, 1)) - 10.0
	_draw_shard_gem_icon(Vector2(gem_x, 16.0))
	LxPixelFont.draw_right(self, shard_txt, 292.0, 18.0, LxPalette.PAL["cream"] if _spark_t > 0.24 else LxPalette.PAL["apricot"], 1)
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_SUBTITLE"), Vector2(28.0, 27.0), LxPalette.PAL["stone"], 1)

	for i: int in range(_upgrades.size()):
		_draw_upgrade_row(i, _upgrades[i])

	# Selected item description box.
	var desc_rect := Rect2(28.0, 134.0, 264.0, 18.0)
	LxPixelFont.draw_panel(self, desc_rect, "night", "mauve", "void")
	if not _feedback_key.is_empty():
		LxPixelFont.draw_centered(self, LxStrings.text(_feedback_key), 160.0, 140.0, LxPalette.color(_feedback_col), 1)
	elif _idx >= 0 and _idx < _upgrades.size():
		var desc_key: String = str(_upgrades[_idx].get("desc_key", ""))
		LxPixelFont.draw_centered(self, LxStrings.text(desc_key), 160.0, 140.0, LxPalette.PAL["cream"], 1)

	LxPixelFont.draw_left(self, LxStrings.text("SHOP_BUY_HINT"), Vector2(28.0, 157.0), LxPalette.PAL["stone"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxStrings.text("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)


func _draw_upgrade_row(i: int, u: Dictionary) -> void:
	var r: Rect2 = _row_rect(i)
	var denied: bool = _deny_t > 0.0 and i == _deny_row
	if denied:
		r.position.x += roundf(sin(_deny_t * 54.0) * 1.6)
	var sel: bool = i == _idx
	var uid: String = str(u.get("id", ""))
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var max_rank: int = int(u.get("max_rank", 1))
	var costs: Array = u.get("costs", []) as Array
	var maxed: bool = rank >= max_rank
	var affordable: bool = Lx.state != null and Lx.state.can_buy_upgrade(uid)

	if sel:
		LxPixelFont.draw_panel(self, r, "plum", "coral" if denied else "gold", "night")
	else:
		LxPixelFont.draw_panel(self, r, "night", "dusk", "void")

	_draw_upgrade_icon(r.position + Vector2(5.0, 3.0), uid, sel)
	var name_key: String = str(u.get("name_key", ""))
	var name_col: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
	LxPixelFont.draw_left(self, LxStrings.text(name_key), r.position + Vector2(16.0, 4.0), name_col, 1)

	# Polished glowing crystal rank pips.
	var pip_x: float = r.position.x + 150.0
	for p: int in range(max_rank):
		var pr := Rect2(pip_x + float(p * 8), r.position.y + 4.0, 5.0, 5.0)
		_draw_rank_pip(pr, p < rank, sel, p, sel and not maxed and affordable and p == rank)
	if _spark_t > 0.0 and i == _spark_row and _spark_pip >= 0:
		_draw_purchase_sparkle(Vector2(pip_x + float(_spark_pip * 8) + 2.0, r.position.y + 6.0))

	if maxed:
		LxPixelFont.draw_right(self, LxStrings.text("SHOP_MAXED"), r.end.x - 6.0, r.position.y + 4.0, LxPalette.PAL["lime"], 1)
	else:
		var cost: int = int(costs[rank]) if rank < costs.size() else 0
		var c_col: Color = LxPalette.PAL["gold"] if affordable else LxPalette.PAL["coral"]
		LxPixelFont.draw_right(self, LxStrings.fmt("SHOP_COST_FMT", [cost]), r.end.x - 6.0, r.position.y + 4.0, c_col, 1)


func _draw_frame_ornaments() -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	# Corner brass rivets with shadow depth.
	for rv: Vector2 in [
		Vector2(p.x + 3.0, p.y + 3.0), Vector2(e.x - 5.0, p.y + 3.0),
		Vector2(p.x + 3.0, e.y - 5.0), Vector2(e.x - 5.0, e.y - 5.0),
	]:
		draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), night)
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), apr)
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), gold)
	# Brass filigree divider beneath header.
	var dy: float = 35.0
	draw_rect(Rect2(28.0, dy, 264.0, 1.0), night)
	draw_rect(Rect2(32.0, dy, 256.0, 1.0), dusk)
	var x: float = 36.0
	while x < 284.0:
		draw_rect(Rect2(x, dy, 3.0, 1.0), apr if int(x) % 12 == 0 else dusk)
		x += 6.0
	draw_rect(Rect2(158.0, dy, 5.0, 1.0), apr)
	draw_rect(Rect2(159.0, dy - 1.0, 3.0, 3.0), gold)
	draw_rect(Rect2(160.0, dy, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_brazier_icon(at: Vector2) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var tip: float = 0.0 if fmod(_elapsed * 5.2, 1.0) < 0.5 else 1.0
	var flare: bool = _spark_t > 0.0
	var bright: bool = flare or fmod(_elapsed * 2.6, 1.0) < 0.55
	if flare:
		draw_rect(Rect2(x + 3.0, y - 2.0, 1.0, 2.0), LxPalette.PAL["cream"])
		draw_rect(Rect2(x + 2.0, y - 1.0, 3.0, 2.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(x + 1.0, y - 2.0, 1.0, 1.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(x + 5.0, y - 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x + 2.0 + tip, y, 1.0, 1.0), LxPalette.PAL["cream"] if bright else LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 2.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 3.0, y + 1.0, 1.0, 2.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 2.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 3.0, y + 3.0, 1.0, 1.0), LxPalette.PAL["cream"])
	# Brazier brass bowl & pedestal.
	draw_rect(Rect2(x, y + 4.0, 7.0, 1.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(x + 1.0, y + 5.0, 5.0, 1.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 2.0, y + 6.0, 3.0, 1.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(x + 1.0, y + 7.0, 5.0, 1.0), LxPalette.PAL["night"])


func _draw_shard_gem_icon(at: Vector2) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var glint: bool = fmod(_elapsed * 2.2, 1.0) < 0.45
	draw_rect(Rect2(x + 3.0, y, 1.0, 1.0), LxPalette.PAL["cream"] if glint else LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 1.0, 2.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x + 4.0, y + 3.0, 1.0, 2.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(x + 2.0, y + 5.0, 3.0, 1.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(x + 3.0, y + 6.0, 1.0, 1.0), LxPalette.PAL["wine"])
	if glint:
		draw_rect(Rect2(x + 5.0, y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_upgrade_icon(at: Vector2, uid: String, sel: bool) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var rows: Array = UPGRADE_ICONS.get(uid, DEFAULT_ICON) as Array
	for r_i: int in range(rows.size()):
		var row: String = str(rows[r_i])
		for c_i: int in range(row.length()):
			var ch: String = row[c_i]
			if ch == ".":
				continue
			var key: String = str(ICON_PAL.get(ch, "cream"))
			draw_rect(Rect2(x + float(c_i), y + float(r_i), 1.0, 1.0), LxPalette.color(key))
	if sel and fmod(_elapsed * 3.0, 1.0) < 0.45:
		draw_rect(Rect2(x + 6.0, y, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_rank_pip(pr: Rect2, filled: bool, sel: bool, idx: int, next_buy: bool = false) -> void:
	draw_rect(pr.grow(1.0), LxPalette.PAL["gold"] if (next_buy and fmod(_elapsed * 3.6, 1.0) < 0.55) else (LxPalette.PAL["apricot"] if next_buy else LxPalette.PAL["void"]))
	if not filled:
		draw_rect(pr, LxPalette.PAL["night"])
		draw_rect(Rect2(pr.position.x + 1.0, pr.end.y - 1.0, 4.0, 1.0), LxPalette.PAL["dusk"])
		draw_rect(Rect2(pr.end.x - 1.0, pr.position.y + 1.0, 1.0, 4.0), LxPalette.PAL["dusk"])
		draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["gold"] if next_buy else LxPalette.PAL["dusk"])
		return
	var shimmer: bool = fmod(_elapsed * 2.5 + float(idx) * 0.35, 1.0) < 0.4
	draw_rect(pr, LxPalette.PAL["apricot"])
	draw_rect(Rect2(pr.position.x + 1.0, pr.position.y, 3.0, 5.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(pr.position.x, pr.position.y + 1.0, 5.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
	if shimmer or sel:
		draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 1.0, 1.0, 3.0), LxPalette.PAL["cream"])


func _draw_purchase_sparkle(center: Vector2) -> void:
	var prog: float = clampf(1.0 - (_spark_t / SPARK_DUR), 0.0, 1.0)
	var dist: float = roundf(3.0 + prog * 7.0)
	var d_diag: float = roundf(dist * 0.7)
	var col: Color = LxPalette.PAL["cream"] if prog < 0.3 else (LxPalette.PAL["gold"] if prog < 0.65 else LxPalette.PAL["apricot"])
	var dirs: Array[Vector2] = [
		Vector2(dist, 0.0), Vector2(-dist, 0.0), Vector2(0.0, dist), Vector2(0.0, -dist),
		Vector2(d_diag, d_diag), Vector2(-d_diag, d_diag), Vector2(d_diag, -d_diag), Vector2(-d_diag, -d_diag),
	]
	if prog < 0.35:
		draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
		draw_rect(Rect2(center + Vector2(-3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
	for off: Vector2 in dirs:
		draw_rect(Rect2((center + off).round(), Vector2(1.0, 1.0)), col)


func _row_rect(i: int) -> Rect2:
	return Rect2(28.0, 38.0 + float(i) * 15.0, 264.0, 13.0)


func _close_btn_rect() -> Rect2:
	return Rect2(230.0, 154.0, 62.0, 11.0)


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
