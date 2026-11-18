extends SceneTree
# Нормализация кадров пака Jampa, версия 4.
# В каждом исходном кадре лежит ДВА персонажа: целый и обрезок соседнего кадра
# (нарезка была с перехлёстом). Обрезок вырезаем по связным компонентам и оставляем
# только главного персонажа. Дальше — выравнивание по общей линии ступней.

const SRC := "res://assets/jampa/"
const PAD_BOTTOM := 6
const WALK_OUTLIER := 20.0
const WHO := ["guy1", "guy2"]

func _init() -> void:
	var max_h := 0
	for who in WHO:
		for f in _pngs(SRC + str(who)):
			var im := Image.load_from_file(SRC + str(who) + "/" + f)
			if im == null:
				continue
			max_h = maxi(max_h, _clean(im).get_used_rect().size.y)
	var cell_h := max_h + PAD_BOTTOM
	var feet := cell_h - PAD_BOTTOM
	print("cell_h=", cell_h, " feet_y=", feet)
	for who in WHO:
		var dir: String = SRC + str(who)
		var out_dir: String = SRC + "norm_" + str(who)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var files := _pngs(dir)
		var centers := {}
		var walk_centers: Array = []
		for f in files:
			var im := Image.load_from_file(dir + "/" + f)
			if im == null:
				continue
			var img := _clean(im)
			var r := img.get_used_rect()
			var c := float(r.position.x) + float(r.size.x) * 0.5
			centers[f] = c
			if f.begins_with("walk_"):
				walk_centers.append(c)
		walk_centers.sort()
		var med: float = walk_centers[walk_centers.size() / 2] if walk_centers.size() > 0 else 0.0
		# Горизонтальный pivot: средний центр ступней по каждой анимации.
		# Единое смещение на всю анимацию — внутри цикла ничего не дёргается.
		var shift := {}
		var group_sum := {}
		var group_cnt := {}
		for f in files:
			var im2 := Image.load_from_file(dir + "/" + f)
			if im2 == null:
				continue
			var g: String = _group(str(f))
			group_sum[g] = float(group_sum.get(g, 0.0)) + _feet_cx(_clean(im2))
			group_cnt[g] = int(group_cnt.get(g, 0)) + 1
		for g in group_sum:
			var mean: float = float(group_sum[g]) / float(group_cnt[g])
			shift[g] = clampf(130.0 - mean, -30.0, 30.0)
		var saved := 0
		var dropped: Array = []
		for f in files:
			if f.begins_with("walk_") and absf(float(centers[f]) - med) > WALK_OUTLIER:
				dropped.append(f)
				continue
			var src := Image.load_from_file(dir + "/" + f)
			if src == null:
				continue
			var img := _clean(src)
			var r := img.get_used_rect()
			var canvas := Image.create(src.get_width(), cell_h, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			if r.size.x > 0 and r.size.y > 0:
				# X как в листе + поправка pivot анимации, низ арта — на линии ступней
				var dx: int = int(round(float(shift[_group(str(f))])))
				canvas.blit_rect(img, r, Vector2i(r.position.x + dx, feet - r.size.y))
			canvas.save_png(out_dir + "/" + f)
			saved += 1
		print(str(who), ": saved=", saved, " dropped=", str(dropped), " walk_median=", snappedf(med, 0.1))
	quit()

func _group(f: String) -> String:
	if f.begins_with("walk_"):
		return "walk"
	if f.begins_with("punch1"):
		return "punch1"
	if f.begins_with("punch2"):
		return "punch2"
	if f.begins_with("jump"):
		return "jump"
	return f.get_basename()

# Центр ступней: средний X непрозрачных пикселей в нижних 8 строках арта.
func _feet_cx(im: Image) -> float:
	var r := im.get_used_rect()
	if r.size.y <= 0:
		return 130.0
	var bottom := r.position.y + r.size.y
	var sum := 0.0
	var cnt := 0
	for y in range(maxi(r.position.y, bottom - 8), bottom):
		for x in range(r.position.x, r.position.x + r.size.x):
			if im.get_pixel(x, y).a > 0.5:
				sum += float(x)
				cnt += 1
	return (sum / float(cnt)) if cnt > 0 else 130.0

# Оставляем только крупные связные компоненты непрозрачных пикселей.
func _clean(src: Image) -> Image:
	var im: Image = src.duplicate()
	im.convert(Image.FORMAT_RGBA8)
	var w: int = im.get_width()
	var h: int = im.get_height()
	var seen := {}
	var comps: Array = []
	for y in range(h):
		for x in range(w):
			if seen.has(y * w + x) or im.get_pixel(x, y).a < 0.3:
				continue
			var stack: Array = [Vector2i(x, y)]
			var pixels: Array = []
			seen[y * w + x] = true
			while stack.size() > 0:
				var p: Vector2i = stack.pop_back()
				pixels.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var k: int = q.y * w + q.x
					if seen.has(k):
						continue
					if im.get_pixel(q.x, q.y).a < 0.3:
						continue
					seen[k] = true
					stack.append(q)
			comps.append(pixels)
	if comps.size() <= 1:
		return im
	# главный компонент + всё, что пересекается с его рамкой (рука, нога могут
	# оказаться отдельным куском). Дальние обрезки соседних кадров уходят.
	var main_comp: Array = comps[0]
	for c in comps:
		if c.size() > main_comp.size():
			main_comp = c
	# Оставляем ТОЛЬКО самого крупного персонажа: в кадрах пака рядом с ним лежит
	# заметный обрезок второго тела, и он «едет» вместе с героем как вторая половина.
	for c in comps:
		if c == main_comp:
			continue
		for p in c:
			im.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	return im

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
