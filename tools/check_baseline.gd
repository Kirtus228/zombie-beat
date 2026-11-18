extends SceneTree
# У всех кадров низ арта должен лежать на одной линии (feet_y = 221).
func _init() -> void:
	var bad := 0
	for who in ["norm_guy1", "norm_guy2"]:
		for f in _pngs("res://assets/jampa/" + str(who) + "/"):
			var im := Image.load_from_file("res://assets/jampa/" + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var bottom := r.position.y + r.size.y
			if bottom != 221:
				print("BAD %s/%s bottom=%d" % [who, f, bottom])
				bad += 1
	print("frames_bad=", bad)
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
