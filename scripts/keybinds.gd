extends RefCounted
## Раскладка клавиш: хранится в user://keys.cfg, применяется к InputMap при старте.
## Мышь и геймпад не трогаем — заменяем только клавиши, иначе удар по ЛКМ терялся.

const PATH := "user://keys.cfg"

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"attack", "jump", "run", "mute", "restart",
]

const TITLES := {
	"move_left": "Влево",
	"move_right": "Вправо",
	"move_up": "Вверх",
	"move_down": "Вниз",
	"attack": "Удар",
	"jump": "Прыжок",
	"run": "Бег",
	"mute": "Звук",
	"restart": "Заново",
}

# Значения из project.godot: к ним возвращает «Сброс».
const DEFAULTS := {
	"move_left": 65,      # A
	"move_right": 68,     # D
	"move_up": 87,        # W
	"move_down": 83,      # S
	"attack": 32,         # Space (ЛКМ остаётся отдельным событием)
	"jump": 75,           # K
	"run": 4194325,       # Shift
	"mute": 77,           # M
	"restart": 82,        # R
}


static func set_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	# убираем только клавиши: мышью и геймпадом продолжаем играть как раньше
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	if keycode <= 0:
		return
	var k := InputEventKey.new()
	k.physical_keycode = keycode
	InputMap.action_add_event(action, k)


static func key_of(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode > 0:
			return int(ev.physical_keycode)
	return 0


static func key_label(action: String) -> String:
	var code := key_of(action)
	if code <= 0:
		return "—"
	return OS.get_keycode_string(code)


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for action in ACTIONS:
		if not cfg.has_section_key("keys", action):
			continue
		var code := int(cfg.get_value("keys", action))
		if code > 0:
			set_key(action, code)


static func save(action: String, keycode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # сохраняем остальные действия, а не только это
	cfg.set_value("keys", action, keycode)
	cfg.save(PATH)


static func reset() -> void:
	for action in ACTIONS:
		set_key(action, int(DEFAULTS.get(action, 0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
