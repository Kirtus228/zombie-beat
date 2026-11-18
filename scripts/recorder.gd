extends Node
# Самозапись кадров: запуск с "-- --capture" делает 10 снимков экрана раз в секунду.
# Нужна, чтобы проверять игру по кадрам, а не по хрупким внешним скриншотам.

const OUT_DIR := "D:/OneDrive/Desktop/Mobidick/games/zombie-beat/caps"
# запись включается файлом-маркером capture.on рядом с project.godot
var total := 26
var interval := 1.0
var shots := 0
var elapsed := 0.0
var busy := false

func _ready() -> void:
	# в capture.on можно задать "кадров:интервал", например 40:0.15 — быстрая съёмка анимации
	var f := FileAccess.open("res://capture.on", FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text().strip_edges()
	f.close()
	if txt.contains(":"):
		var parts := txt.split(":")
		total = maxi(1, int(parts[0]))
		interval = maxf(0.05, float(parts[1]))

func _log_state(idx: int) -> void:
	# Числа к кадру: где герой, где враги, какая дистанция. По скриншоту это не измерить.
	var m: Node = get_parent()
	if m == null or m.player == null:
		return
	var line := "cap_%02d wave=%d hits=%d atk=%d maxdx=%.0f hp=%d player=(%.0f,%.0f) cam=(%.0f,%.0f) done=%s %s" % [
		idx, m.wave, m.hits, int(m.attacks), float(m.max_hit_d), m.player.hp, m.player.position.x, m.player.position.y,
		m.cam.position.x, m.cam.position.y, str(m.finished), m.result
	]
	for e in m.enemies:
		line += " | e=(%.0f,%.0f) s=%d c=%d st=%.2f d=%.0f %s %s" % [
			e.position.x, e.position.y, int(e.get_meta("slot", -1)), e.combo, e.stun,
			e.position.distance_to(m.player.position),
			"dead" if e.dead else ("ATK" if e == m.attacker else "wait"),
			str(e.state) + " to=" + str(snappedf(float(e.get_meta("to_len", -1.0)), 0.1))
		]
	var path := "%s/state.log" % OUT_DIR
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE if idx == 0 else FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()

func _process(delta: float) -> void:
	if shots >= total or busy:
		return
	elapsed += delta
	if elapsed < interval:
		return
	elapsed = 0.0
	busy = true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/cap_%02d.png" % [OUT_DIR, shots])
	_log_state(shots)
	shots += 1
	busy = false
	if shots >= total:
		get_tree().quit()
