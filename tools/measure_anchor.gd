extends SceneTree
# Ищем стабильный якорь кадра: центр по полосам высоты. У кого меньше разброс — к тому и привязываем.
const SRC := "res://assets/jampa/"

func _init() -> void:
	for who in ["guy1", "guy2"]:
		var rows := {}
		for f in _pngs(SRC + str(who)):
			var im := Image.load_from_file(SRC + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var y0 := r.position.y
			var h := r.size.y
			var bands := {}
			for b in [["head", 0.0, 0.15], ["chest", 0.15, 0.40], ["waist", 0.40, 0.60], ["feet", 0.85, 1.0]]:
				var a := y0 + int(h * b[1])
				var z := y0 + int(h * b[2])
				var sum := 0.0
				var cnt := 0
				for y in range(a, maxi(a + 1, z)):
					for x in range(r.position.x, r.position.x + r.size.x):
						if im.get_pixel(x, y).a > 0.5:
							sum += float(x)
							cnt += 1
				bands[b[0]] = (sum / float(cnt)) if cnt > 0 else -1.0
			for k in bands:
				if not rows.has(k):
					rows[k] = []
				rows[k].append(bands[k])
		print("=== ", who)
		for k in ["head", "chest", "waist", "feet"]:
			var arr: Array = rows[k]
			var mn := 1e9
			var mx := -1e9
			for v in arr:
				mn = minf(mn, v)
				mx = maxf(mx, v)
			print("%-6s range=%.1f min=%.1f max=%.1f" % [k, mx - mn, mn, mx])
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
