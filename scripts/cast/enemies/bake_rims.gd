## Bakes the rimmed body and flash sheets enemy_kit loads (art/cast/enemies/<id>/rimmed/): each sheet laid over
## its rim (enemy.gd rim_image), so a body draws in one call from one texture instead of rim + body, and no sheet
## is read back from the GPU mid-run. Rerun it whenever the sheets are re-exported, then re-import:
##   "$GODOT" --headless --path . --script res://scripts/cast/enemies/bake_rims.gd
## A sheet with a partly transparent pixel on its rim isn't baked (one texture can't match two blended draws
## there): enemy.gd then bakes its rim at run time and draws the two, as before.
extends SceneTree

const ENEMY := preload("res://scripts/cast/enemies/enemy.gd")
const KIT := preload("res://scripts/cast/enemies/enemy_kit.gd")
const DIRECTOR := preload("res://scripts/game/run/director.gd")
const LAYERS: Array[String] = ["body", "flash"]


func _init() -> void:
	var baked := 0
	var skipped := PackedStringArray()
	for id: String in DIRECTOR.KINDS:
		var json := KIT.ROOT + id + "/" + id + ".json"
		if not FileAccess.file_exists(json):
			continue
		var sheets := {}
		_sheets(JSON.parse_string(FileAccess.get_file_as_string(json))["animations"], sheets)
		for rel: String in sheets:
			var img := Image.load_from_file(ProjectSettings.globalize_path(KIT.ROOT + id + "/" + rel))
			img.convert(Image.FORMAT_RGBA8)
			var out := ENEMY.rim_image(img)
			if not _exact(img, out):
				skipped.append(id + "/" + rel)
				continue
			out.blit_rect_mask(img, img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			var path := KIT.rimmed(id, rel)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			out.save_png(ProjectSettings.globalize_path(path))
			baked += 1
	print("BAKE RIMS baked %d, skipped %d %s" % [baked, skipped.size(), skipped])
	quit()


## Every body and flash sheet path (relative to the kind's folder) anywhere under `v`.
func _sheets(v: Variant, into: Dictionary) -> void:
	if not v is Dictionary:
		return
	for k: String in v:
		var s: Variant = v[k]
		if s is String and LAYERS.has(k) and str(s).ends_with(".png"):
			into[s] = true
		else:
			_sheets(s, into)


## One draw of the sheet over its rim matches the two draws: no partly transparent sheet pixel lies on the rim.
func _exact(img: Image, rim: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a8
			if a != 0 and a != 255 and rim.get_pixel(x, y).a8 != 0:
				return false
	return true
