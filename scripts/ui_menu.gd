extends CanvasLayer
## Заставка, главное меню и настройки клавиш.
## Живёт поверх игры; пока меню открыто, дерево сцен на паузе (см. main.gd).

signal play_pressed

const Keybinds := preload("res://scripts/keybinds.gd")

enum Screen { SPLASH, MENU, SETTINGS }

const C_BG := Color(0.04, 0.05, 0.09, 0.72)
const C_TEXT := Color(0.86, 0.89, 0.94)
const C_DIM := Color(0.60, 0.65, 0.72)
const C_ACCENT := Color(0.95, 0.82, 0.34)
const C_BLOOD := Color(0.72, 0.20, 0.18)

var screen: int = Screen.SPLASH
var listening := ""

var root: Control
var splash_box: Control
var press_label: Label
var menu_box: Control
var menu_buttons: Array[Button] = []
var settings_box: Control
var key_buttons := {}
var settings_buttons: Array[Button] = []
var settings_hint: Label
var _t := 0.0
var _shown_at := 0   # мс, когда экран открылся: гасит «двойное» нажатие Enter


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_build_splash()
	_build_menu()
	_build_settings()
	_show(Screen.SPLASH)


func _process(delta: float) -> void:
	_t += delta
	if screen == Screen.SPLASH and press_label:
		press_label.modulate.a = 0.45 + 0.55 * absf(sin(_t * 2.2))


# --- построение экранов -----------------------------------------------------

func _build_splash() -> void:
	# арт живёт на самом низу и остаётся фоном и в меню, и в настройках,
	# поэтому он первый ребёнок root и настраивается ДО добавления в дерево
	var art := TextureRect.new()
	art.texture = load("res://assets/ui/splash.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(art)

	splash_box = Control.new()
	splash_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(splash_box)

	# затемнение снизу, чтобы текст читался на любом кадре арта
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -190.0
	shade.offset_bottom = 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_box.add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -320.0
	box.offset_right = 320.0
	box.offset_top = -186.0
	box.offset_bottom = -26.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	splash_box.add_child(box)

	var title := Label.new()
	title.text = "ZOMBIE BEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", C_BLOOD)
	title.add_theme_color_override("font_outline_color", Color(0.10, 0.03, 0.03))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "НОЧЬ.  УЛИЦА.  КОГТИ."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", C_ACCENT)
	box.add_child(sub)

	press_label = Label.new()
	press_label.text = "нажми любую клавишу"
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.add_theme_font_size_override("font_size", 22)
	press_label.add_theme_color_override("font_color", C_TEXT)
	press_label.position = Vector2(0, 0)
	box.add_child(press_label)


func _build_menu() -> void:
	menu_box = _panel_box()
	var col: VBoxContainer = menu_box.get_meta("box")
	_add_title(col, "ZOMBIE BEAT", 52, C_BLOOD)
	_add_spacer(col, 24)
	menu_buttons.clear()
	for item in [["ИГРАТЬ", _on_play], ["НАСТРОЙКИ", _on_settings], ["ВЫХОД", _on_quit]]:
		var b := _add_button(col, String(item[0]), 30)
		b.pressed.connect(item[1])
		menu_buttons.append(b)


func _build_settings() -> void:
	settings_box = _panel_box()
	var col: VBoxContainer = settings_box.get_meta("box")
	_add_title(col, "НАСТРОЙКИ", 38, C_ACCENT)
	var tip := Label.new()
	tip.text = "выбери действие и нажми новую клавишу"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", C_DIM)
	col.add_child(tip)
	_add_spacer(col, 10)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 2)
	col.add_child(grid)
	key_buttons.clear()
	settings_buttons.clear()
	for action in Keybinds.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.text = String(Keybinds.TITLES.get(action, action))
		name_label.custom_minimum_size = Vector2(200, 0)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", C_TEXT)
		row.add_child(name_label)
		var keyb := _add_button(row, Keybinds.key_label(action), 16)
		keyb.custom_minimum_size = Vector2(170, 26)
		keyb.pressed.connect(_on_rebind.bind(action))
		key_buttons[action] = keyb
		settings_buttons.append(keyb)
		grid.add_child(row)

	settings_hint = Label.new()
	settings_hint.text = " "
	settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_hint.add_theme_font_size_override("font_size", 18)
	settings_hint.add_theme_color_override("font_color", C_ACCENT)
	col.add_child(settings_hint)
	_add_spacer(col, 10)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 18)
	var reset_btn := _add_button(row2, "СБРОС", 18)
	reset_btn.custom_minimum_size = Vector2(150, 34)
	reset_btn.pressed.connect(_on_reset)
	var back := _add_button(row2, "НАЗАД", 18)
	back.custom_minimum_size = Vector2(150, 34)
	back.pressed.connect(_on_back)
	col.add_child(row2)
	settings_buttons.append(reset_btn)
	settings_buttons.append(back)


func _panel_box() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrap)
	var dim := ColorRect.new()
	dim.color = C_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -330.0
	box.offset_right = 330.0
	box.offset_top = -258.0
	box.offset_bottom = 258.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	wrap.add_child(box)
	wrap.set_meta("box", box)
	return wrap


func _add_title(box: Control, text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	box.add_child(l)


func _add_spacer(box: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	box.add_child(s)


func _add_button(box: Control, text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", size)
	box.add_child(b)
	return b


# --- переключение экранов ---------------------------------------------------

func _show(which: int) -> void:
	screen = which
	_shown_at = Time.get_ticks_msec()
	listening = ""
	splash_box.visible = which == Screen.SPLASH
	menu_box.visible = which == Screen.MENU
	settings_box.visible = which == Screen.SETTINGS
	# фокус ставим отложенно: в момент смены экрана кнопка ещё не в дереве
	# в настройках фокус уходил на первую строку, и то же нажатие Enter,
	# которым открыли экран, сразу запускало переназначение
	if which == Screen.MENU and not menu_buttons.is_empty():
		menu_buttons[0].grab_focus.call_deferred()
	if which == Screen.SETTINGS and not settings_buttons.is_empty():
		settings_buttons[0].grab_focus.call_deferred()


func _on_play() -> void:
	play_pressed.emit()


func _on_settings() -> void:
	_refresh_keys()
	_show(Screen.SETTINGS)


func _on_back() -> void:
	_cancel_listen()
	_show(Screen.MENU)


func _on_quit() -> void:
	get_tree().quit()


func _on_reset() -> void:
	Keybinds.reset()
	_refresh_keys()
	settings_hint.text = "раскладка сброшена"


func _on_rebind(action: String) -> void:
	if Time.get_ticks_msec() - _shown_at < 250:
		return
	_cancel_listen()
	listening = action
	var b: Button = key_buttons[action]
	b.text = "нажми клавишу…"
	b.add_theme_color_override("font_color", C_ACCENT)
	settings_hint.text = "ждём клавишу для «%s» · Esc — отмена" % String(Keybinds.TITLES.get(action, action))


func _cancel_listen() -> void:
	if listening == "":
		return
	var b: Button = key_buttons.get(listening, null)
	if b:
		b.text = Keybinds.key_label(listening)
		b.remove_theme_color_override("font_color")
	listening = ""
	settings_hint.text = " "


func _refresh_keys() -> void:
	for action in key_buttons:
		var b: Button = key_buttons[action]
		b.text = Keybinds.key_label(action)
		b.remove_theme_color_override("font_color")


# --- ввод -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			# физический код надёжнее для раскладок, но у событий из тестов и
			# эмуляторов он бывает нулевым — тогда берём обычный keycode
			var key: int = int(event.physical_keycode)
			if key <= 0:
				key = int(event.keycode)
			if key == KEY_ESCAPE:
				_cancel_listen()
			else:
				Keybinds.set_key(listening, key)
				Keybinds.save(listening, key)
				var action := listening
				listening = ""
				var b: Button = key_buttons[action]
				b.text = Keybinds.key_label(action)
				b.remove_theme_color_override("font_color")
				settings_hint.text = "«%s» → %s" % [String(Keybinds.TITLES.get(action, action)), Keybinds.key_label(action)]
			get_viewport().set_input_as_handled()
		return

	if screen == Screen.SPLASH:
		var go := false
		if event is InputEventKey and event.pressed and not event.echo:
			go = true
		elif event is InputEventMouseButton and event.pressed:
			go = true
		if go:
			_show(Screen.MENU)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and int(event.physical_keycode) == KEY_ESCAPE:
		if screen == Screen.SETTINGS:
			_on_back()
			get_viewport().set_input_as_handled()
