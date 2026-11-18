extends SceneTree
# Что за полоса перекрывает персонажа: сканируем строку пикселей и печатаем участки одного цвета.
func _init() -> void:
	var im := Image.load_from_file("res://caps/cap_16.png")
	if im == null:
		print("no image")
		quit()
		return
	im.convert(Image.FORMAT_RGBA8)
	for y in [205, 240, 300]:
		var line := "y=%d: " % y
		var prev := ""
		var start := 0
		for x in range(500, 760):
			var c := im.get_pixel(x, y)
			var key := "%d,%d,%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
			if key != prev:
				if prev != "":
					line += "[%d-%d %s]" % [start, x - 1, prev]
				prev = key
				start = x
		line += "[%d-759 %s]" % [start, prev]
		print(line)
	quit()
