extends Node2D
# Тень под персонажем: тёмный эллипс, рисуется кодом.

var width := 46.0
var height := 12.0

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * width * 0.5, sin(a) * height * 0.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
