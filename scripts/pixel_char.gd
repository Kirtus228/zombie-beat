extends Node2D
# Пиксельный персонаж, собранный из целочисленных блоков (1 блок = 1 пиксель кадра).
# Узел масштабируется в 3 раза, поэтому каждый блок = ровно один пиксель экрана 320x180:
# получается честный пиксель-арт, но рисунок наш собственный (без чужих спрайтов).
# Спрайт 24x40: голова 14x11, торс, шорты, руки, ноги, обводка и двухтоновая тень.

var pose := "idle"
var t := 0.0
var facing := 1
var is_zombie := false
var flash := 0.0

# палитра: 10 цветов, как в аркадных спрайтах
var c_outline := Color("12100f")
var c_skin := Color("f7d7b6")
var c_skin_dark := Color("d3a077")
var c_shirt := Color("f0e5c6")
var c_shirt_dark := Color("c8b48a")
var c_shorts := Color("3d4460")
var c_shorts_dark := Color("252b40")
var c_hair := Color("2a1f17")
var c_white := Color("f2f2ea")
var c_pupil := Color("1a1414")
var c_lips := Color("b85c4e")

func _draw() -> void:
	var s := float(facing)
	# анимационные сдвиги
	var bob := 0
	var leg_a := 0
	var leg_b := 0
	var arm_a := 0
	var arm_b := 0
	var lean := 0
	match pose:
		"idle":
			bob = 1 if int(t * 2.4) % 2 == 0 else 0
			leg_a = 1
			leg_b = -1
		"walk":
			var ph := int(t * 9.0) % 4
			leg_a = [3, 0, -3, 0][ph]
			leg_b = -leg_a
			arm_a = -leg_a
			arm_b = leg_a
			bob = 1 if ph % 2 == 0 else 0
		"punch1", "punch2":
			lean = 1
			arm_a = 8
			arm_b = -2
			leg_a = 2
			leg_b = -2
		"hurt":
			lean = -2
			arm_a = -1
			arm_b = -1
		"down":
			return  # лежачего рисуем отдельным проходом ниже

	_draw_standing(s, bob, leg_a, leg_b, arm_a, arm_b, lean)

	if flash > 0.0:
		px(4, 0, 16, 40, Color(1, 1, 1, flash * 0.5))

func _draw_standing(s: float, bob: int, leg_a: int, leg_b: int, arm_a: int, arm_b: int, lean: int) -> void:
	var oy := -bob
	var base_y := 14 + oy
	var lx := 6 - lean

	# --- ноги (штанины + голени + стопы) ---
	px(lx - 1, 31 + oy, 7, 6, c_outline)
	px(lx, 31 + oy, 6, 5, c_shorts_dark)
	px(lx + 8, 31 + oy, 7, 6, c_outline)
	px(lx + 9, 31 + oy, 6, 5, c_shorts_dark)
	# левая нога
	px(lx + 1 + maxi(leg_a, 0), 36 + oy, 4, 4, c_outline)
	px(lx + 2 + maxi(leg_a, 0), 36 + oy, 3, 3, c_skin_dark)
	px(lx + 1 + leg_a, 39 + oy, 6, 2, c_outline)
	px(lx + 2 + leg_a, 39 + oy, 5, 1, c_skin)
	# правая нога
	px(lx + 10 - maxi(-leg_b, 0), 36 + oy, 4, 4, c_outline)
	px(lx + 11 - maxi(-leg_b, 0), 36 + oy, 3, 3, c_skin_dark)
	px(lx + 9 + leg_b, 39 + oy, 6, 2, c_outline)
	px(lx + 10 + leg_b, 39 + oy, 5, 1, c_skin)

	# --- шорты ---
	px(lx - 1, 25 + oy, 18, 8, c_outline)
	px(lx, 25 + oy, 16, 7, c_shorts)
	px(lx + 9, 25 + oy, 7, 7, c_shorts_dark)
	px(lx, 25 + oy, 16, 1, c_shorts_dark)

	# --- торс: футболка, скос плеч, тень справа ---
	px(lx - 2, base_y + 2, 20, 11, c_outline)
	px(lx - 1, base_y + 3, 18, 9, c_shirt)
	px(lx + 9, base_y + 3, 8, 9, c_shirt_dark)
	px(lx - 1, base_y + 3, 18, 1, c_shirt_dark)
	# ворот
	px(lx + 7, base_y + 2, 4, 1, c_outline)

	# --- руки ---
	# задняя
	px(lx - 3 - maxi(arm_b, 0), base_y + 4, 4, 9, c_outline)
	px(lx - 2 - maxi(arm_b, 0), base_y + 5, 2, 7, c_skin_dark)
	# передняя
	px(lx + 16 + maxi(arm_a, 0), base_y + 4, 4 + maxi(arm_a, 0), 4, c_outline)
	px(lx + 17, base_y + 5, 2 + maxi(arm_a, 0), 2, c_skin)
	px(lx + 17, base_y + 8, 3, 6, c_outline)
	px(lx + 18, base_y + 9, 2, 4, c_skin)

	# --- шея и голова ---
	px(lx + 8, 11 + oy, 5, 4, c_outline)
	px(lx + 9, 11 + oy, 3, 3, c_skin_dark)

	var hx := lx + 2
	var hy := 0 + oy
	# череп с обводкой
	px(hx + 1, hy, 12, 2, c_outline)
	px(hx, hy + 2, 14, 8, c_outline)
	px(hx + 1, hy + 10, 12, 2, c_outline)
	px(hx + 1, hy + 1, 12, 9, c_skin)
	px(hx + 11, hy + 1, 2, 9, c_skin_dark)
	# уши
	px(hx - 1, hy + 4, 1, 3, c_outline)
	px(hx + 14, hy + 4, 1, 3, c_outline)
	# волосы: шапка ступеньками, блик
	px(hx + 1, hy + 0, 12, 3, c_hair)
	px(hx + 0, hy + 2, 2, 3, c_hair)
	px(hx + 12, hy + 2, 2, 3, c_hair)
	px(hx + 2, hy + 1, 4, 1, c_hair.lightened(0.25))
	# брови
	px(hx + 3, hy + 4, 3, 1, c_hair)
	px(hx + 8, hy + 4, 3, 1, c_hair)
	# глаза: белок, зрачок, блик
	px(hx + 3, hy + 5, 3, 2, c_outline)
	px(hx + 4, hy + 5, 2, 2, c_white if not is_zombie else Color("e8e8c8"))
	px(hx + 5, hy + 6, 1, 1, c_pupil if not is_zombie else Color("6a1e14"))
	px(hx + 8, hy + 5, 3, 2, c_outline)
	px(hx + 8, hy + 5, 2, 2, c_white if not is_zombie else Color("e8e8c8"))
	px(hx + 8, hy + 6, 1, 1, c_pupil if not is_zombie else Color("6a1e14"))
	# нос
	px(hx + 7, hy + 7, 1, 2, c_skin_dark)
	# рот с губами
	if is_zombie:
		px(hx + 5, hy + 9, 5, 2, c_outline)
		px(hx + 6, hy + 9, 3, 1, Color("f2f2e0"))
	else:
		px(hx + 5, hy + 9, 5, 1, c_lips)
		px(hx + 6, hy + 10, 3, 1, c_lips.darkened(0.25))

func px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(float(x), float(y), float(w), float(h)), color)
