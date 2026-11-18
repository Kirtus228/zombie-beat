extends SceneTree
# Проверка нормализованных кадров: арт не должен упираться в границы новой ячейки.
const SRC := "res://assets/jampa/"

func _init() -> void:
	for who in ["norm_guy1", "norm_guy2"]:
		for f in _pngs(SRC + str(who)):
			var im := Image.load_from_file(SRC + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var edge := []
			if r.position.x <= 0: edge.append("LEFT")
			if r.position.y <= 0: edge.append("TOP")
			if r.position.x + r.size.x >= im.get_width(): edge.append("RIGHT")
			if r.position.y + r.size.y >= im.get_height(): edge.append("BOT")
			if edge.size() > 0:
				print("%s/%s %dx%d rect=%s %s" % [who, f, im.get_width(), im.get_height(), r, ",".join(edge)])
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
