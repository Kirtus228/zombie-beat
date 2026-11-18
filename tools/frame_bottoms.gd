extends SceneTree
# Что реально с рамками нормализованных кадров.
func _init() -> void:
	for who in ["norm_guy1", "norm_guy2"]:
		print("=== ", who)
		for f in _pngs("res://assets/jampa/" + str(who) + "/"):
			var im := Image.load_from_file("res://assets/jampa/" + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			print("%-14s y=%3d h=%3d bottom=%3d" % [f, r.position.y, r.size.y, r.position.y + r.size.y])
	quit()

func _pngs(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".png"):
			out.append(n)
		n = d.get_next()
	out.sort()
	return out
