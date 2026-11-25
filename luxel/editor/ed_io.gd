extends RefCounted
## Lossless room IO for the level editor: keeps ints as ints, key order and the house format
## (2-space JSON, .map header lines untouched) so a saved room only differs where it was edited.

const EDITS_DIR: String = "res://docs/level_edits"

static var work_dir: String = "user://editor"  # checks point this elsewhere so they never touch an open editor's files


static func parse_json(text: String) -> Dictionary:
	# str_to_var keeps 500 an int and 0.0 a float; JSON.parse_string turns every number into a float.
	var v: Variant = str_to_var(text)
	if v is Dictionary:
		return v as Dictionary
	var j: Variant = JSON.parse_string(text)
	return j as Dictionary if j is Dictionary else {}


static func to_json(d: Variant) -> String:
	return JSON.stringify(d, "  ", false)


static func ascii(t: String) -> String:
	var out := PackedStringArray()
	for i: int in range(t.length()):
		var c: int = t.unicode_at(i)
		out.append(t[i] if c < 128 else "\\u%04x" % c)
	return "".join(out)


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func write(path: String, text: String) -> bool:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("editor: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	return true


static func read_json(path: String, fallback: Variant = {}) -> Variant:
	var txt: String = read(path)
	if txt.is_empty():
		return fallback
	var v: Variant = str_to_var(txt)
	return v if v != null else fallback


static func append_line(path: String, line: String) -> void:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()


static func stamp_now() -> String:
	return Time.get_datetime_string_from_system(false, true)


static func vec(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return LxMapFormat.to_vec2(v, fallback)


static func num(f: float) -> Variant:
	## Whole numbers go back to the file as ints, like the rest of the room files.
	return int(roundf(f)) if is_equal_approx(f, roundf(f)) else snappedf(f, 0.01)


static func arr(p: Vector2) -> Array:
	return [num(p.x), num(p.y)]
