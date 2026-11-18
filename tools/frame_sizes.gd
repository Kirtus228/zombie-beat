extends SceneTree
# Ширина и высота арта по кадрам: обрезки сразу видны (полоска вместо тела).
func _init() -> void:
	for who in ["guy1", "guy2"]:
		print("=== ", who)
		var d := "res://assets/jampa/" + str(who) + "/"
		for f in _pngs(d):
			var im := Image.load_from_file(d + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			print("%-14s w=%3d h=%3d" % [f, r.size.x, r.size.y])
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
