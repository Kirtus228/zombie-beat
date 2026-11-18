extends SceneTree
# Проверка боя: серия из 5 ударов роняет врага (но не убивает) — он встаёт с остатком HP;
# недобитая серия оставляет только оглушение. Смерть — когда кончились HP.
# Запуск: godot --headless --path games/zombie-beat --script tools/test_combo.gd

func hit(e: Node2D) -> void:
	e.invuln = 0.0
	e.take_hit(12, 1)

func _init() -> void:
	var F = load("res://scripts/fighter.gd")
	var fails := 0

	# 1) четыре удара: жив, оглушён, серия копится
	var e: Node2D = F.new()
	e.is_enemy = true
	e.hp = 90
	for i in range(1, 5):
		hit(e)
		if e.dead or e.knocked:
			print("FAIL: упал на %d-м ударе" % i); fails += 1
		if e.stun <= 0.0:
			print("FAIL: нет оглушения после %d-го удара" % i); fails += 1
		if e.combo != i:
			print("FAIL: combo=%d вместо %d" % [e.combo, i]); fails += 1

	# 2) пятый подряд: падение, но не смерть
	hit(e)
	if not e.knocked:
		print("FAIL: на 5-м ударе не упал"); fails += 1
	if e.dead:
		print("FAIL: упал насмерть, а должен встать"); fails += 1
	if e.state != "down":
		print("FAIL: состояние %s вместо down" % e.state); fails += 1

	# 3) пока лежит — его не бьют, он не бьёт; потом встаёт с остатком HP
	var hp_before: int = e.hp
	hit(e)
	if e.hp != hp_before:
		print("FAIL: лежачего ударили"); fails += 1
	e.knock_timer = 0.01
	e._process(0.05)
	if e.knocked:
		print("FAIL: не встал"); fails += 1
	if e.dead:
		print("FAIL: встал мёртвым"); fails += 1
	if e.state != "idle":
		print("FAIL: после подъёма состояние %s" % e.state); fails += 1
	if e.hp <= 0 or e.hp > 90:
		print("FAIL: HP после подъёма %d" % e.hp); fails += 1

	# 4) серия не рвётся, а враги добиваются по HP
	var e2: Node2D = F.new()
	e2.is_enemy = true
	e2.hp = 36
	for i in range(3):
		hit(e2)
	if not e2.dead:
		print("FAIL: не умер, когда кончились HP (%d)" % e2.hp); fails += 1

	# 5) недобитая серия: 3 удара, серия сброшена — падения нет
	var e3: Node2D = F.new()
	e3.is_enemy = true
	e3.hp = 90
	for k in range(3):
		for i in range(3):
			hit(e3)
		e3.combo = 0
		hit(e3)
		if e3.knocked:
			print("FAIL: упал без пяти подряд"); fails += 1
	if e3.stun <= 0.0:
		print("FAIL: нет оглушения в недобитой серии"); fails += 1

	print("fails=%d" % fails)
	if fails == 0:
		print("OK: 5 подряд — падение и подъём с остатком HP, меньше — оглушение 1.5 с, смерть по HP")
	quit(1 if fails > 0 else 0)
