extends SceneTree
# Диагностика: насколько гуляет тело внутри кадра. Считаем центр bbox и центр «ступней».
const SRC := "res://assets/jampa/"

func _init() -> void:
	for who in ["guy2"]:
		for f in _pngs(SRC + str(who)):
			var im := Image.load_from_file(SRC + str(who) + "/" + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var r := im.get_used_rect()
			var foot_y := r.position.y + int(r.size.y * 0.80)
			var sum := 0.0
			var cnt := 0
			for y in range(foot_y, r.position.y + r.size.y):
				for x in range(r.position.x, r.position.x + r.size.x):
					if im.get_pixel(x, y).a > 0.5:
						sum += float(x)
						cnt += 1
			var foot_cx := (sum / float(cnt)) if cnt > 0 else -1.0
			print("%s bbox_x=%d w=%d cx=%.1f foot_cx=%.1f" % [f, r.position.x, r.size.x, float(r.position.x) + float(r.size.x) * 0.5, foot_cx])
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
