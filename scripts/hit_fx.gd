extends Node2D
# Вспышка удара: звёздочка с обводкой, гаснет за 0.22 с.

const LIFE := 0.22

var life := LIFE
var size := 13.0
var tint := Color(1.0, 0.93, 0.4)
var slash := 0.0   # != 0 — к удар добавить росчерк когтей (направление ±1)

func _ready() -> void:
	z_index = 500
	scale = Vector2(1.2, 1.2)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(life / LIFE, 0.0, 1.0)
	# гаснет только в конце: в первой половине жизни вспышка должна быть яркой,
	# иначе на тёмной улице от неё остаётся серая клякса
	# яркость держится почти всю жизнь и рвётся в конце: иначе на тёмной улице
	# вспышка полжизни висит серой кляксой поверх персонажей
	var a := clampf(k * 5.0, 0.0, 1.0)
	var r := size * (0.7 + 0.65 * (1.0 - k))
	_spike(r, Color(tint.r, tint.g, tint.b, a))
	_spike(r * 0.45, Color(1, 1, 1, a))
	if slash != 0.0:
		# три росчерка когтей СВЕРХУ ВНИЗ: видно, что это царапина, а не удар кулаком
		var dir := Vector2(slash * 0.5, 1.0).normalized()
		var perp := Vector2(-dir.y, dir.x) * signf(slash)
		var l := 30.0 * (1.0 + 0.35 * (1.0 - k))
		var c := Color(1.0, 0.97, 0.9, a * 0.9)
		for i in range(3):
			var off: Vector2 = perp * (float(i - 1) * 6.0)
			draw_line(off - dir * l * 0.55, off + dir * l * 0.45, c, 1.5)

func _spike(r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var rad: float = r if i % 2 == 0 else r * 0.42
		pts.append(Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, color)
