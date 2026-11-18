extends SceneTree
# Проверка после нормализации v2: насколько центр тела гуляет по кадрам ходьбы.
const SRC := "res://assets/jampa/norm_guy2/"

func _init() -> void:
	var arr := []
	for f in _pngs(SRC):
		var im := Image.load_from_file(SRC + f)
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		var r := im.get_used_rect()
		arr.append(snappedf(float(r.position.x) + float(r.size.x) * 0.5, 0.1))
	print("bbox centers: ", arr)
	var mn := 1e9
	var mx := -1e9
	for v in arr:
		mn = minf(mn, v)
		mx = maxf(mx, v)
	print("spread=", snappedf(mx - mn, 0.1), " cell_center=", 260.0 / 2.0)
	quit()

func _pngs(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.begins_with("walk_") and n.ends_with(".png"):
			out.append(n)
		n = d.get_next()
	out.sort()
	return out
