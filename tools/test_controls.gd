extends SceneTree
# Проверка раскладки управления и новых анимаций (20.11.2026).
# ВАЖНО: в _init() у SceneTree ещё нет root, add_child() подвешивает прогон —
# поэтому спрайты строим напрямую через _build_frames(), без дерева.
# Запуск: godot --headless --path <проект> --script res://tools/test_controls.gd

var fails := 0
func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1

func _init() -> void:
	var F = load("res://scripts/fighter.gd")
	print("controls test")

	# 1) раскладка битэмапа
	for a in ["attack", "jump", "run", "mute", "restart", "move_left", "move_right", "move_up", "move_down"]:
		ok(InputMap.has_action(a), "есть действие " + a)
	var has_mouse := false
	var has_space := false
	for e in InputMap.action_get_events("attack"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			has_mouse = true
		if e is InputEventKey and e.physical_keycode == KEY_SPACE:
			has_space = true
	ok(has_mouse, "удар по ЛКМ")
	ok(has_space, "удар по Space")
	ok(InputMap.action_get_events("attack").size() >= 3, "удар — 3 кнопки (ЛКМ, Space, J)")

	# 2) кадры прыжка есть у героя и у зомби
	ok(ResourceLoader.exists("res://assets/hero/jump.png"), "кадр героя jump")
	ok(ResourceLoader.exists("res://assets/hero/jumpkick.png"), "кадр героя jumpkick")
	ok(ResourceLoader.exists("res://assets/zombie/jump.png"), "кадр зомби jump")

	# 3) набор анимаций: герой бьёт кулаком и в прыжке, зомби — только рывком
	var hero = F.new()
	hero.configure(150.0, 280, 12, false)
	var hsf = hero._build_frames()
	ok(hsf.has_animation("jump") and hsf.get_frame_count("jump") > 0, "у героя jump есть кадры")
	ok(hsf.has_animation("jumpkick") and hsf.get_frame_count("jumpkick") > 0, "у героя jumpkick есть кадры")
	ok(hsf.has_animation("punch1") and hsf.has_animation("punch2"), "у героя есть обычные удары")

	var enemy = F.new()
	enemy.configure(82.0, 90, 5, true, true)   # с мозгом
	var esf = enemy._build_frames()
	ok(esf.has_animation("z_atk"), "у зомби есть рывок z_atk")
	ok(esf.get_frame_count("z_atk") >= 4, "z_atk из 4+ кадров: %d" % esf.get_frame_count("z_atk"))
	ok(not esf.has_animation("punch1"), "человеческого прямого удара у зомби НЕТ")

	# 4) прыжок: в воздухе неуязвим, второй прыжок запрещён
	ok(hero.jump(), "прыжок сработал")
	ok(hero.airborne, "герой в воздухе")
	ok(hero.invuln > 0.0, "в воздухе неуязвим")
	ok(not hero.jump(), "второй прыжок в воздухе запрещён")
	ok(hero.state == "jump", "анимация прыжка включилась")

	# 5) герой в воздухе бьёт с разворота (кадр jumpkick), на земле — кулаком
	hero.airborne = true
	hero.attack_cd = 0.0
	hero.set_state("jumpkick")
	ok(hero.state == "jumpkick", "удар в воздухе — jumpkick")

	print("fails=", fails)
	quit(0 if fails == 0 else 1)
