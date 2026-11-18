extends SceneTree
# Диагностика прозрачности: если в кадре есть непрозрачный прямоугольник фона,
# он будет «ездить» за персонажем.
const DIRS := ["res://assets/jampa/norm_guy1/", "res://assets/jampa/norm_guy2/"]

func _init() -> void:
	for d in DIRS:
		for f in _pngs(d):
			var im := Image.load_from_file(d + f)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			var w := im.get_width()
			var h := im.get_height()
			var corners := [im.get_pixel(0, 0).a, im.get_pixel(w - 1, 0).a, im.get_pixel(0, h - 1).a, im.get_pixel(w - 1, h - 1).a]
			var opaque := 0
			for y in range(h):
				for x in range(w):
					if im.get_pixel(x, y).a > 0.5:
						opaque += 1
			print("%s%s alpha_corners=%s opaque=%d of %d" % [d.get_slice("/", 3), f, str(corners), opaque, w * h])
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
