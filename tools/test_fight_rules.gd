extends SceneTree
# Проверка правил боя (#001/#002/#004) без запуска сцены.

func _init() -> void:
	var F = load("res://scripts/fighter.gd")
	var Main = load("res://scripts/main.gd")
	var m = Main.new()
	var fails := 0

	# не кладём в дерево: в _init() у SceneTree ещё нет root
	m.world = Node2D.new()

	m.player = F.new()
	m.player.configure(150.0, 280, 12, false)
	m.player.position = Vector2(400, 400)

	# --- #002: врага продавить нельзя, двигается только игрок
	var e1 = F.new()
	e1.configure(90.0, 90, 5, true)
	e1.position = Vector2(360, 400)
	var bx: float = e1.position.x
	m._resolve_overlap(e1, m.player, 64.0, 24.0, 0.0, 1.0)
	if absf(e1.position.x - bx) > 0.01:
		print("FAIL #002: враг сдвинулся на %.2f" % (e1.position.x - bx)); fails += 1
	if m.player.position.x <= 400.0:
		print("FAIL #002: игрока не вытолкнуло"); fails += 1

	m.player.position = Vector2(400, 400)

	# --- #004: один удар задевает не больше двух, ближайших по глубине
	var group: Array[Node2D] = []
	for dy in [0.0, 12.0, 24.0]:
		var e = F.new()
		e.configure(90.0, 90, 5, true)
		e.position = Vector2(460, 400 + dy)
		e.set_meta("slot", 0)
		m.world.add_child(e)
		group.append(e)
	m.enemies = group
	m.player.facing = 1
	m._resolve_player_hit()
	if m.last_hit_n != 2:
		print("FAIL #004: удар задел %d целей вместо 2" % m.last_hit_n); fails += 1

	# --- #001: мгновенного удара нет — сначала замах
	var empty: Array[Node2D] = []
	m.enemies = empty
	var e2 = F.new()
	e2.configure(90.0, 90, 5, true)
	e2.position = Vector2(450, 400)
	e2.set_meta("slot", 0)
	m.world.add_child(e2)
	var one: Array[Node2D] = [e2]
	m.enemies = one
	m.player.hp = 280
	m.player.invuln = 0.0
	m.strike_lock = 0.0
	m._update_enemies(0.016)
	if m.player.hp != 280:
		print("FAIL #001: урон пришёл в кадре начала замаха (hp=%d)" % m.player.hp); fails += 1
	if float(e2.get_meta("windup", 0.0)) <= 0.0:
		print("FAIL #001: замах не начался"); fails += 1

	# --- #001: в конце замаха удар НЕ бьёт мгновенно: урон ждёт кадра когтей
	m.player.hp = 280
	m.player.invuln = 0.0
	e2.attack_cd = 0.0
	m._enemy_strike(e2)
	if float(e2.get_meta("contact", -1.0)) <= 0.0:
		print("FAIL #001: касание не запланировано"); fails += 1
	if m.player.hp != 280:
		print("FAIL #001: урон пришёл в начале рывка (hp=%d)" % m.player.hp); fails += 1
	# касание наступает через Z_CONTACT_T — тогда урон и проходит
	m._update_enemies(F.Z_CONTACT_T + 0.02)
	if m.player.hp != 275:
		print("FAIL #001: удар в зоне не прошёл (hp=%d)" % m.player.hp); fails += 1

	m.player.hp = 280
	m.player.invuln = 0.0
	e2.attack_cd = 0.0
	e2.position = Vector2(450, 470)
	m._enemy_strike(e2)
	m._update_enemies(F.Z_CONTACT_T + 0.02)
	if m.player.hp != 280:
		print("FAIL #001: удар прошёл вне зоны (hp=%d)" % m.player.hp); fails += 1

	print("fails=%d" % fails)
	if fails == 0:
		print("OK: замах вместо мгновенного удара, враг не продавливается, удар задевает не больше двух")
	quit(1 if fails > 0 else 0)
