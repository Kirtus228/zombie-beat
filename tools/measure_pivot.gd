extends SceneTree
# Где на самом деле ступни в каждом кадре (после вырезания фантомов).
# Если центр ступней гуляет относительно центра кадра — тень уезжает из-под ног.
func _init() -> void:
	for who in ["norm_guy1", "norm_guy2"]:
		print("=== ", who)
		for f in _pngs("res://assets/jampa/" + str(who) + "/"):
			var im := Image.load_from_file("res://assets/jampa/" + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var bottom := r.position.y + r.size.y
			var sum := 0.0
			var cnt := 0
			for y in range(maxi(r.position.y, bottom - 8), bottom):
				for x in range(r.position.x, r.position.x + r.size.x):
					if im.get_pixel(x, y).a > 0.5:
						sum += float(x)
						cnt += 1
			var cx := (sum / float(cnt)) if cnt > 0 else -1.0
			print("%-14s feet_cx=%.1f cell_mid=130 off=%.1f" % [f, cx, cx - 130.0])
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
