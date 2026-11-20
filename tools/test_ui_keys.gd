extends SceneTree
# Проверка раскладки: переназначение клавиши реально меняет InputMap и пишется в файл.
# Запуск: Godot --headless --script res://tools/test_ui_keys.gd

const Keybinds := preload("res://scripts/keybinds.gd")
const UiMenu := preload("res://scripts/ui_menu.gd")

var fails := 0

func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("FAIL: ", msg)
		fails += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	# 1) клавиша ставится в InputMap
	Keybinds.set_key("attack", KEY_F)
	ok(Keybinds.key_of("attack") == KEY_F, "удар переназначен на F")
	ok(Keybinds.key_label("attack") == "F", "подпись клавиши: %s" % Keybinds.key_label("attack"))

	# 2) запись и чтение из user://keys.cfg
	Keybinds.save("attack", KEY_F)
	ok(FileAccess.file_exists(Keybinds.PATH), "файл раскладки создан")
	Keybinds.set_key("attack", KEY_SPACE)
	Keybinds.load_saved()
	ok(Keybinds.key_of("attack") == KEY_F, "после перезагрузки удар снова на F")

	# 3) сброс возвращает дефолт и убирает файл
	Keybinds.reset()
	ok(Keybinds.key_of("attack") == int(Keybinds.DEFAULTS["attack"]), "сброс вернул Space")
	ok(not FileAccess.file_exists(Keybinds.PATH), "файл раскладки удалён")

	# 4) экран настроек: клик по строке + нажатие клавиши меняет раскладку
	var menu := UiMenu.new()
	root.add_child(menu)
	await process_frame   # без кадра _ready ещё не собрал экраны
	menu._show(2)         # экран настроек
	menu._shown_at = 0    # снимаем защиту от «того же Enter»
	menu._on_rebind("jump")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C
	ev.pressed = true
	menu._input(ev)
	ok(Keybinds.key_of("jump") == KEY_C, "через экран настроек прыжок переехал на C")
	ok(menu.key_buttons["jump"].text == "C", "кнопка показывает C")

	# 5) Esc отменяет выбор и не меняет раскладку
	var before := Keybinds.key_of("run")
	menu._on_rebind("run")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	menu._input(esc)
	ok(Keybinds.key_of("run") == before, "Esc отменил переназначение")

	Keybinds.reset()
	print("fails=", fails)
	quit(1 if fails > 0 else 0)
