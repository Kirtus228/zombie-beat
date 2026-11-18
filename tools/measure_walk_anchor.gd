extends SceneTree
# Разброс якорей ТОЛЬКО внутри цикла ходьбы: именно там видно, как тело ползёт по кадру.
const SRC := "res://assets/jampa/"

func _init() -> void:
	for who in ["guy1", "guy2"]:
		print("=== ", who)
		var anchors := {"bbox": [], "head": [], "waist": [], "low4": []}
		for f in _pngs(SRC + str(who)):
			var im := Image.load_from_file(SRC + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var y0 := r.position.y
			var h := r.size.y
			anchors["bbox"].append(float(r.position.x) + float(r.size.x) * 0.5)
			anchors["head"].append(_band(im, r, y0, y0 + maxi(1, int(h * 0.15))))
			anchors["waist"].append(_band(im, r, y0 + int(h * 0.40), y0 + int(h * 0.60)))
			anchors["low4"].append(_band(im, r, r.position.y + r.size.y - 4, r.position.y + r.size.y))
		for k in ["bbox", "head", "waist", "low4"]:
			var arr: Array = anchors[k]
			var mn := 1e9
			var mx := -1e9
			for v in arr:
				mn = minf(mn, v)
				mx = maxf(mx, v)
			print("%-6s range=%5.1f  %s" % [k, mx - mn, str(arr.map(func(v): return snappedf(v, 0.1)))])
	quit()

func _band(im: Image, r: Rect2i, a: int, z: int) -> float:
	var sum := 0.0
	var cnt := 0
	for y in range(maxi(a, r.position.y), mini(z, r.position.y + r.size.y)):
		for x in range(r.position.x, r.position.x + r.size.x):
			if im.get_pixel(x, y).a > 0.5:
				sum += float(x)
				cnt += 1
	return (sum / float(cnt)) if cnt > 0 else -1.0

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
