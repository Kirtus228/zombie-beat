class_name Sfx
extends Node
# Звук боя и зомби. Всё синтезировано своими руками (tools/make_sfx.mjs),
# чужих сэмплов и лицензий нет.
#
# Автозагрузки нет специально: узел создаётся сам при первом звуке. Иначе
# глобальное имя Sfx не видно при запуске тестов через --script, и скрипты
# боя не компилируются.
const PATHS := {
	"swing": "res://assets/sfx/swing.ogg",
	"hit": "res://assets/sfx/hit.ogg",
	"player_hurt": "res://assets/sfx/player_hurt.ogg",
	"z_attack": "res://assets/sfx/z_attack.ogg",
	"z_hurt": "res://assets/sfx/z_hurt.ogg",
	"z_death": "res://assets/sfx/z_death.ogg",
	"z_groan": "res://assets/sfx/z_groan.ogg",
}
const POOL := 10        # одновременных звуков: серия ударов не обрывает предыдущий
const BASE_DB := -7.0

static var _me: Sfx = null
static var plays := 0      # диагностика: сколько звуков реально запущено

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

static func play(key: String, db := 0.0, pitch := 1.0) -> void:
	if _me == null or not is_instance_valid(_me):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return
		_me = Sfx.new()
		_me.name = "Sfx"
		tree.root.add_child(_me)
	_me._play(key, db, pitch)

# разброс высоты тона: одинаковые удары не звучат как один
static func play_var(key: String, db := 0.0, spread := 0.07) -> void:
	play(key, db, randf_range(1.0 - spread, 1.0 + spread))

# для тестов: сколько звуков загружено и что играет прямо сейчас
static func info() -> Dictionary:
	if _me == null or not is_instance_valid(_me):
		return {}
	var playing := 0
	for p in _me._players:
		if p.playing:
			playing += 1
	return {"streams": _me._streams.size(), "pool": _me._players.size(), "playing": playing}

func _ready() -> void:
	for key in PATHS:
		if ResourceLoader.exists(PATHS[key]):
			_streams[key] = load(PATHS[key])
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _play(key: String, db: float, pitch: float) -> void:
	if not _streams.has(key) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key]
	p.volume_db = BASE_DB + db
	p.pitch_scale = pitch
	p.play()
	plays += 1
