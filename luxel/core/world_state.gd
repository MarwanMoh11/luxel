class_name LxWorldState
extends RefCounted
## Scoped world-state variable store and condition evaluator (Lx.vars).
## Scopes: "game", "island:<n>", "dungeon:<id>", "room:<island>:<region>".
## Persisted inside LxGameState.world_vars; old saves load clean as {}.

signal var_changed(scope: String, name: String, value: Variant)

var _local_vars: Dictionary = {}


func _backing() -> Dictionary:
	if Lx.state != null and is_instance_valid(Lx.state):
		return Lx.state.world_vars
	return _local_vars


func get_var(scope: String, var_name: String, default: Variant = "") -> Variant:
	var sc: String = scope.strip_edges()
	var nm: String = var_name.strip_edges()
	if nm.is_empty():
		return default
	var root: Dictionary = _backing()
	if root.has(sc) and root[sc] is Dictionary:
		var sd: Dictionary = root[sc] as Dictionary
		if sd.has(nm):
			return sd[nm]
	if default is String and (default as String).is_empty() and Lx.packs != null:
		var sv: Dictionary = Lx.packs.state_vars()
		if sv.has(nm) and sv[nm] is Dictionary:
			var meta: Dictionary = sv[nm] as Dictionary
			if meta.has("default"):
				return meta["default"]
	return default


func set_var(scope: String, var_name: String, value: Variant) -> void:
	var sc: String = scope.strip_edges()
	if sc.is_empty():
		sc = "game"
	var nm: String = var_name.strip_edges()
	if nm.is_empty():
		return
	var root: Dictionary = _backing()
	var sd: Dictionary = root[sc] as Dictionary if (root.has(sc) and root[sc] is Dictionary) else {}
	if sd.has(nm) and typeof(sd[nm]) == typeof(value) and sd[nm] == value:
		return
	sd[nm] = value
	root[sc] = sd
	var_changed.emit(sc, nm, value)


func clear_scope(scope: String) -> void:
	var root: Dictionary = _backing()
	if root.has(scope):
		root.erase(scope)


func clear_all() -> void:
	_backing().clear()
	_local_vars.clear()


func to_dict() -> Dictionary:
	return _backing().duplicate(true)


func from_dict(d: Dictionary) -> void:
	var root: Dictionary = _backing()
	root.clear()
	for k: Variant in d.keys():
		if d[k] is Dictionary:
			root[str(k)] = (d[k] as Dictionary).duplicate(true)


func resolve_var(var_name: String, island: int = 0, region: String = "", default: Variant = "") -> Variant:
	var nm: String = var_name.strip_edges()
	if nm.is_empty():
		return default
	var root: Dictionary = _backing()
	# Explicit scope syntax: "island:2.tide" or "game.tide"
	var dot: int = nm.rfind(".")
	if dot > 0:
		var exp_scope: String = nm.left(dot).strip_edges()
		var exp_name: String = nm.substr(dot + 1).strip_edges()
		if root.has(exp_scope) and root[exp_scope] is Dictionary and (root[exp_scope] as Dictionary).has(exp_name):
			return (root[exp_scope] as Dictionary)[exp_name]
		return get_var(exp_scope, exp_name, default)

	var scopes: Array[String] = []
	if island > 0 and not region.is_empty():
		scopes.append("room:%d:%s" % [island, region])
		if Lx.packs != null:
			var did: String = Lx.packs.dungeon_of(island, region)
			if not did.is_empty():
				scopes.append("dungeon:" + did)
	if island > 0:
		scopes.append("island:%d" % island)
	scopes.append("game")

	for sc: String in scopes:
		if root.has(sc) and root[sc] is Dictionary:
			var sd: Dictionary = root[sc] as Dictionary
			if sd.has(nm):
				return sd[nm]

	if Lx.packs != null:
		var sv: Dictionary = Lx.packs.state_vars()
		if sv.has(nm) and sv[nm] is Dictionary and (sv[nm] as Dictionary).has("default"):
			return (sv[nm] as Dictionary)["default"]
	return default


## Evaluates condition grammar:
## `name==v`, `name!=v`, `name>=n`, `name<=n`, `name>n`, `name<n`, `flag:<f>`, `!flag:<f>`,
## grouped with nested `( )`, negated with `!`, joined by ` && ` / ` || `.
## Supports explicit scopes like `dungeon:<id>.<var>`, `island:<n>.<var>`, `room:<n>:<r>.<var>`, `game.<var>`.
func eval(cond: String, island: int = 0, region: String = "") -> bool:
	var trimmed: String = _strip_outer_parens(cond.strip_edges())
	if trimmed.is_empty():
		return true
	var or_parts: PackedStringArray = _split_top_level(trimmed, "||")
	for or_raw: String in or_parts:
		var and_parts: PackedStringArray = _split_top_level(or_raw.strip_edges(), "&&")
		var all_ok: bool = true
		for term_raw: String in and_parts:
			if not _eval_atom(term_raw.strip_edges(), island, region):
				all_ok = false
				break
		if all_ok:
			return true
	return false


func _eval_atom(raw_atom: String, island: int, region: String) -> bool:
	var atom: String = _strip_outer_parens(raw_atom.strip_edges())
	if atom.is_empty():
		return true
	if _has_top_level_op(atom, "||") or _has_top_level_op(atom, "&&"):
		return eval(atom, island, region)
	if atom == "true":
		return true
	if atom == "false":
		return false
	if atom.begins_with("!flag:"):
		return not _check_flag(atom.substr(6).strip_edges())
	if atom.begins_with("flag:"):
		return _check_flag(atom.substr(5).strip_edges())
	if atom.begins_with("!"):
		return not _eval_atom(atom.substr(1).strip_edges(), island, region)

	for op: String in ["==", "!=", ">=", "<=", ">", "<"]:
		var idx: int = _find_top_level(atom, op)
		if idx > 0:
			var lhs_name: String = atom.left(idx).strip_edges()
			var rhs_str: String = atom.substr(idx + op.length()).strip_edges()
			var lhs_val: Variant = resolve_var(lhs_name, island, region, "")
			return _compare(lhs_val, op, rhs_str)

	var v: Variant = resolve_var(atom, island, region, false)
	return _is_truthy(v)


static func _strip_outer_parens(s: String) -> String:
	var cur: String = s.strip_edges()
	while cur.length() >= 2 and cur[0] == "(" and cur[cur.length() - 1] == ")":
		var depth: int = 0
		var in_q: String = ""
		var encloses: bool = true
		for i: int in range(cur.length()):
			var ch: String = cur[i]
			if not in_q.is_empty():
				if ch == in_q:
					in_q = ""
				continue
			if ch == "\"" or ch == "'":
				in_q = ch
			elif ch == "(":
				depth += 1
			elif ch == ")":
				depth -= 1
				if depth == 0 and i < cur.length() - 1:
					encloses = false
					break
		if encloses and depth == 0:
			cur = cur.substr(1, cur.length() - 2).strip_edges()
		else:
			break
	return cur


static func _split_top_level(s: String, sep: String) -> PackedStringArray:
	var out := PackedStringArray()
	var n: int = s.length()
	var slen: int = sep.length()
	var depth: int = 0
	var in_q: String = ""
	var start: int = 0
	var i: int = 0
	while i < n:
		var ch: String = s[i]
		if not in_q.is_empty():
			if ch == in_q:
				in_q = ""
			i += 1
			continue
		if ch == "\"" or ch == "'":
			in_q = ch
			i += 1
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(0, depth - 1)
		elif depth == 0 and i + slen <= n and s.substr(i, slen) == sep:
			var part: String = s.substr(start, i - start).strip_edges()
			if not part.is_empty():
				out.append(part)
			i += slen
			start = i
			continue
		i += 1
	var tail: String = s.substr(start).strip_edges()
	if not tail.is_empty():
		out.append(tail)
	return out


static func _has_top_level_op(s: String, op: String) -> bool:
	return _find_top_level(s, op) >= 0


static func _find_top_level(s: String, op: String) -> int:
	var n: int = s.length()
	var olen: int = op.length()
	var depth: int = 0
	var in_q: String = ""
	for i: int in range(n - olen + 1):
		var ch: String = s[i]
		if not in_q.is_empty():
			if ch == in_q:
				in_q = ""
			continue
		if ch == "\"" or ch == "'":
			in_q = ch
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(0, depth - 1)
		elif depth == 0 and s.substr(i, olen) == op:
			return i
	return -1


static func _compare(lhs: Variant, op: String, rhs_str: String) -> bool:
	if op in [">=", "<=", ">", "<"]:
		var a: float = _to_num(lhs)
		var b: float = float(rhs_str) if rhs_str.is_valid_float() else 0.0
		match op:
			">=": return a >= b
			"<=": return a <= b
			">": return a > b
			"<": return a < b
	var ls: String = _norm_val_str(lhs)
	var rs: String = rhs_str.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	if ls.is_valid_float() and rs.is_valid_float():
		var eq_n: bool = is_equal_approx(float(ls), float(rs))
		return eq_n if op == "==" else not eq_n
	var eq: bool = ls == rs
	return eq if op == "==" else not eq


static func _to_num(v: Variant) -> float:
	if v is int or v is float:
		return float(v)
	var s: String = str(v).strip_edges()
	return float(s) if s.is_valid_float() else 0.0


static func _norm_val_str(v: Variant) -> String:
	if v is bool:
		return "true" if bool(v) else "false"
	return str(v).strip_edges()


static func _is_truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return bool(v)
	if v is int or v is float:
		return not is_zero_approx(float(v))
	var s: String = str(v).strip_edges().to_lower()
	return not s.is_empty() and s != "false" and s != "0"


static func _check_flag(flag: String) -> bool:
	return LxRegionLoader.check_flag_static(flag)
