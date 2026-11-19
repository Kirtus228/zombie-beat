extends Node2D
# Улица, волны зомби, HUD. Прототип на 2 минуты: 3 волны, победа/поражение.

const Fighter := preload("res://scripts/fighter.gd")
const HitFx := preload("res://scripts/hit_fx.gd")

# границы с запасом на ширину спрайта: у края боец не должен висеть половинкой
const ARENA_MIN_X := 110.0
const ARENA_MAX_X := 1470.0
# полоса глубины: 200 px — в неё влезают места «за спиной» и «перед героем»
const ARENA_TOP := 312.0
const ARENA_BOTTOM := 496.0
const PLAYER_DAMAGE := 12
const ZOMBIE_DAMAGE := 5
const PLAYER_HP := 280
const ZOMBIE_HP := 90   # ~8 ударов по 12: успевает упасть серией и встать, потом добивается   # враг теперь падает только с пятого удара — бой длиннее, HP поднят
const ZOMBIE_ATK_CD := 1.0
# Замах врага перед ударом (#001): враг подходит, стоит и только потом бьёт.
# Свой разброс — иначе толпа бьёт синхронно, как метроном.
const WINDUP_MIN := 0.45
const WINDUP_MAX := 0.9
const MAX_WINDUP := 2   # одновременно готовятся не больше двух
# Четыре места вокруг героя: слева, справа, за спиной, перед ним.
# Четыре места: по два с каждого бока, на разной глубине. Никто не встаёт
# прямо перед героем — иначе его тело накрывает героя и это читается как слипание.
const SLOTS := [Vector2(-72, -28), Vector2(-72, 28), Vector2(72, -28), Vector2(72, 28)]
# запас на мёртвую зону 8 px: место ±84 + 8 → удар должен доставать с 104
# Удар регает ровно на длину руки: рука в кадре удара ~60 px, плюс корпус.
# Было 112 — урон прилетал от тел, стоящих далеко друг от друга.
const REACH_X := 80.0      # вылет удара по горизонтали
const REACH_Y := 34.0      # допуск по глубине: места стоят на ±28
const MAX_HIT_TARGETS := 2  # один удар попадает максимум по двум, и только спереди
const BODY_RX := 64.0      # эллипс корпуса: игрок ↔ враг
const BODY_RY := 24.0
const ENEMY_RX := 56.0     # враг ↔ враг
const ENEMY_RY := 20.0
const STRIKE_GAP := 0.35   # пауза между ударами разных врагов
const WAIT_DIST := 150.0   # где ждёт враг без свободного места
const MAX_ACTIVE := 4      # в кадре до четырёх: остальные ждут за краем
const WAVES := [[3, 0.0], [4, 0.0], [5, 0.0]]
const WAVE_DELAY := 2.5
const RUN_MULT := 1.55   # бег на Shift

var player: Node2D
var enemies: Array[Node2D] = []
var wave := 0
var wave_timer := 0.0
var wave_started := false
var elapsed := 0.0
var finished := false
var result := ""
var hit_done := false

var cam: Camera2D
var hud: CanvasLayer
var bar_fill: ColorRect
var wave_label: Label
var time_label: Label
var msg_label: Label
var hits_label: Label
var hits := 0
var attack_pending := 0.0

var world: Node2D
var demo := false
var attacker: Node2D = null
var pending_spawn := 0
var wave_slot := 0
var strike_lock := 0.0
var groan_timer := 2.5   # когда следующий стон из толпы
var max_hit_d := 0.0 # диагностика: с какой дистанции прошёл последний удар игрока
var last_hit_n := 0  # диагностика: сколько целей задел последний удар
var attacks := 0     # диагностика: сколько ударов сделал герой

func _ready() -> void:
	randomize()
	_build_street()
	_build_player()
	_build_camera()
	# Мир рисуется в 320x180 и растягивается на окно: так получается пиксельный вид.
	world = Node2D.new()
	world.scale = Vector2.ONE
	add_child(world)
	for c in get_children():
		if c is Node2D and c != world:
			c.reparent(world)
	_build_hud()
	_start_music()
	wave_timer = 1.5
	if FileAccess.file_exists("res://capture.on"):
		print("capture mode on")
		# "idle" в маркере — записываем игру как её видит игрок, без автопилота
		var f := FileAccess.open("res://capture.on", FileAccess.READ)
		var txt := f.get_as_text() if f else ""
		if f:
			f.close()
		demo = not txt.contains("idle")
		add_child(load("res://scripts/recorder.gd").new())

# Трек свой (синтез, tools/make_music.mjs), лицензий и авторских прав нет.
func _start_music() -> void:
	var p := "res://assets/music/loop.ogg"
	if not ResourceLoader.exists(p):
		return
	var stream: AudioStreamOggVorbis = load(p)
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -6.0
	add_child(player)
	player.play()

func _build_street() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.11, 0.16)
	bg.size = Vector2(1600, 540)
	add_child(bg)
	var sky := ColorRect.new()
	sky.color = Color(0.13, 0.16, 0.24)
	sky.size = Vector2(1600, 290)
	add_child(sky)
	var road := ColorRect.new()
	road.color = Color(0.16, 0.17, 0.19)
	road.position = Vector2(0, 300)
	road.size = Vector2(1600, 200)
	add_child(road)
	var walkway := ColorRect.new()
	walkway.color = Color(0.22, 0.21, 0.24)
	walkway.position = Vector2(0, 500)
	walkway.size = Vector2(1600, 40)
	add_child(walkway)
	# дома на заднем плане, окна на них и фонари вдоль дороги
	for i in range(0, 1600, 160):
		var house := ColorRect.new()
		house.color = Color(0.11, 0.12, 0.17)
		house.position = Vector2(i - 10, 70 + (i % 5) * 12)
		house.size = Vector2(130, 230)
		add_child(house)
		for r in range(3):
			for c in range(3):
				var win := ColorRect.new()
				win.color = Color(0.42, 0.5, 0.62) if (i + r + c) % 3 else Color(0.75, 0.68, 0.4)
				win.position = Vector2(i + 8 + c * 38, 96 + r * 52 + (i % 5) * 12)
				win.size = Vector2(22, 26)
				add_child(win)
		var pole := ColorRect.new()
		pole.color = Color(0.3, 0.3, 0.34)
		pole.position = Vector2(i + 118, 236)
		pole.size = Vector2(6, 66)
		add_child(pole)
		var lamp := ColorRect.new()
		lamp.color = Color(0.95, 0.85, 0.45)
		lamp.position = Vector2(i + 108, 230)
		lamp.size = Vector2(26, 8)
		add_child(lamp)
	# разметка по центру дороги
	for i in range(0, 1600, 120):
		var dash := ColorRect.new()
		dash.color = Color(0.5, 0.5, 0.45)
		dash.position = Vector2(i, 392)
		dash.size = Vector2(56, 6)
		add_child(dash)

func _build_player() -> void:
	player = Fighter.new()
	player.configure(150.0, PLAYER_HP, PLAYER_DAMAGE, false)
	player.position = Vector2(180, 420)
	player.z_index = 10
	add_child(player)

func _build_camera() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(480, 270)
	add_child(cam)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.45)
	frame.position = Vector2(16, 16)
	frame.size = Vector2(270, 62)
	hud.add_child(frame)
	# полоса здоровья из двух прямоугольников — в 320x180 тема ProgressBar рисует мусор
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.1, 0.12, 0.9)
	bar_bg.position = Vector2(24, 46)
	bar_bg.size = Vector2(252, 22)
	hud.add_child(bar_bg)
	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.85, 0.2, 0.2)
	bar_fill.position = Vector2(26, 48)
	bar_fill.size = Vector2(248, 18)
	hud.add_child(bar_fill)
	var name_label := Label.new()
	name_label.text = "ГЕРОЙ"
	name_label.position = Vector2(24, 20)
	name_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(name_label)
	wave_label = Label.new()
	wave_label.position = Vector2(700, 20)
	wave_label.add_theme_font_size_override("font_size", 26)
	hud.add_child(wave_label)
	time_label = Label.new()
	time_label.position = Vector2(700, 54)
	time_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(time_label)
	hits_label = Label.new()
	hits_label.position = Vector2(40, 100)
	hits_label.add_theme_font_size_override("font_size", 40)
	hits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	hud.add_child(hits_label)
	msg_label = Label.new()
	msg_label.position = Vector2(320, 200)
	msg_label.add_theme_font_size_override("font_size", 46)
	# без обводки текст волны сливался с окнами домов и читался как артефакт
	msg_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	msg_label.add_theme_constant_override("outline_size", 8)

	hud.add_child(msg_label)
	# подсказка по управлению: раскладка битэмапа (удар — ЛКМ/Space, прыжок — K, бег — Shift)
	var hint := Label.new()
	hint.text = "WASD — шаг   SHIFT — бег   ЛКМ / SPACE — удар   K — прыжок   M — звук   R — заново"
	hint.position = Vector2(28, 506)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	hud.add_child(hint)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if finished:
		return
	elapsed += delta
	_update_player(delta)
	if demo:
		_demo_ai(delta)
	_update_enemies(delta)
	_update_groans(delta)
	_cleanup_enemies()
	_update_waves(delta)
	_update_hud()
	if player.dead:
		_finish("ПОРАЖЕНИЕ")
	elif wave >= WAVES.size() and pending_spawn == 0 and enemies.is_empty() and wave_timer <= 0.0:
		_finish("ПОБЕДА")

func _update_player(_delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	# бег на удержание Shift (в битэмапах бег — это удержание, а не отдельная кнопка)
	var run := RUN_MULT if Input.is_action_pressed("run") else 1.0
	player.move_by(dir * player.speed * run * _delta)
	player.position.x = clampf(player.position.x, ARENA_MIN_X, ARENA_MAX_X)
	player.position.y = clampf(player.position.y, ARENA_TOP, ARENA_BOTTOM)
	player.z_index = int(player.position.y)
	cam.position.x = clampf(player.position.x, 480.0, 1120.0)
	if Input.is_action_just_pressed("jump"):
		player.jump()
	if Input.is_action_just_pressed("attack") and player.try_attack():
		attacks += 1
		attack_pending = 0.14
	if attack_pending > 0.0:
		attack_pending -= _delta
		if attack_pending <= 0.0:
			_resolve_player_hit()

func _demo_ai(delta: float) -> void:
	# Автопилот только для записи кадров: идёт к ближайшему и бьёт, чтобы проверять бой.
	var target: Node2D = null
	var best := 1e9
	for e in enemies:
		if e.dead:
			continue
		var d: float = absf(e.position.x - player.position.x)
		if d < best:
			best = d
			target = e
	if target == null:
		return
	var dx: float = target.position.x - player.position.x
	var dy: float = target.position.y - player.position.y
	var dir := Vector2(
		signf(dx) if absf(dx) > 64.0 else 0.0,
		signf(dy) if absf(dy) > 10.0 else 0.0
	)
	# в записи кадров иногда прыгаем и бьём в воздухе — иначе прыжок не увидеть в caps/
	if not player.airborne and randf() < 0.03:
		player.jump()
	if dir.length() > 0.0:
		player.move_by(dir.normalized() * player.speed * delta)
	player.position.x = clampf(player.position.x, ARENA_MIN_X, ARENA_MAX_X)
	player.position.y = clampf(player.position.y, ARENA_TOP, ARENA_BOTTOM)
	if absf(dx) < REACH_X and absf(dy) < REACH_Y and player.try_attack():
		attacks += 1
		attack_pending = 0.14

func _resolve_player_hit() -> void:
	# Удар идёт туда, куда смотрит герой, и достаёт не больше двух ближайших.
	# Раньше он бил всех в радиусе — включая стоящих за спиной.
	var targets: Array[Node2D] = []
	for e in enemies:
		if e.dead or e.knocked:
			continue
		var dx: float = e.position.x - player.position.x
		var dy: float = absf(e.position.y - player.position.y)
		if absf(dx) > REACH_X or dy > REACH_Y:
			continue
		if absf(dx) > 8.0 and int(signf(dx)) != player.facing:
			continue
		targets.append(e)
	last_hit_n = 0
	if targets.is_empty():
		return
	# Сначала те, кто ближе по глубине: удар не должен задевать две разные
	# полосы сразу (#004). Внутри полосы — по расстоянию.
	targets.sort_custom(func(a, b):
		var da: float = absf(a.position.y - player.position.y)
		var db: float = absf(b.position.y - player.position.y)
		if absf(da - db) > 6.0:
			return da < db
		return absf(a.position.x - player.position.x) < absf(b.position.x - player.position.x)
	)
	var n: int = mini(MAX_HIT_TARGETS, targets.size())
	last_hit_n = n
	Sfx.play_var("hit", 0.0, 0.07)
	for i in range(n):
		var e: Node2D = targets[i]
		var dx2: float = e.position.x - player.position.x
		hits += 1
		max_hit_d = maxf(max_hit_d, absf(dx2))
		_spawn_fx(e.position)
		e.take_hit(player.damage, int(signf(dx2)) if dx2 != 0.0 else player.facing)

# Живая толпа: раз в несколько секунд кто-то из зомби стонет.
func _update_groans(delta: float) -> void:
	groan_timer -= delta
	if groan_timer > 0.0:
		return
	groan_timer = randf_range(2.5, 6.0)
	for e in enemies:
		if not e.dead:
			Sfx.play_var("z_groan", -5.0, 0.14)
			return

func _update_enemies(delta: float) -> void:
	if strike_lock > 0.0:
		strike_lock -= delta
	# 1) у каждого врага своё место вокруг героя; кому места нет — ждёт в стороне
	for e in enemies:
		if e.dead:
			continue
		# оглушённый или лежащий не идёт к своему месту и не бьёт; замах сорван
		if e.stun > 0.0 or e.knocked:
			e.set_meta("windup", 0.0)
			if e.state == "z_ready" or e.state == "z_atk":
				e.set_state("idle")
			e.move_by(Vector2.ZERO)
			continue
		# замах: враг стоит на месте и готовится, а не напирает (#001)
		var windup: float = float(e.get_meta("windup", 0.0))
		if windup > 0.0:
			windup = maxf(0.0, windup - delta)
			e.set_meta("windup", windup)
			e.move_by(Vector2.ZERO)
			if windup <= 0.0:
				_enemy_strike(e)
			continue
		var slot: int = int(e.get_meta("slot", -1))
		if slot < 0:
			slot = _claim_slot(e)
			e.set_meta("slot", slot)
		var to := _slot_pos(e, slot) - e.position
		e.set_meta("to_len", snappedf(to.length(), 0.1))
		# мёртвая зона 8 px: иначе враг микродвижениями дёргает анимацию «шаг↔стойка»
		if to.length() > 8.0:
			e.move_by(to.normalized() * e.speed * delta)
		else:
			e.move_by(Vector2.ZERO)
	# 2) разведение эллипсом: корпуса не перекрываются ни по X, ни по глубине
	for i in range(enemies.size()):
		var a: Node2D = enemies[i]
		if a.dead:
			continue
		if not player.dead:
			# Врага продавить нельзя (#002): двигается только сам герой, враг
			# стоит на месте. Иначе ГГ толкал тело перед собой и бил неуязвимую
			# цель, которая «уезжала» вместе с ударом.
			_resolve_overlap(a, player, BODY_RX, BODY_RY, 0.0, 1.0)
		for j in range(i + 1, enemies.size()):
			var b: Node2D = enemies[j]
			if b.dead:
				continue
			_resolve_overlap(a, b, ENEMY_RX, ENEMY_RY)
	# 3) границы, глубина, лицо к герою
	for e in enemies:
		if e.dead:
			continue
		e.position.x = clampf(e.position.x, ARENA_MIN_X - 260.0, ARENA_MAX_X + 360.0)
		e.position.y = clampf(e.position.y, ARENA_TOP, ARENA_BOTTOM)
		e.z_index = int(e.position.y)
		e.facing = 1 if player.position.x >= e.position.x else -1
	# 4) удары по очереди: кто встал на место раньше — бьёт раньше
	if strike_lock > 0.0 or player.dead:
		return
	# пока герой в неуязвимости, удары не тратятся впустую: иначе враг бьёт,
	# урон не проходит, а кулдаун сгорает — и толпа почти не наносит урона
	if player.invuln > 0.0:
		return
	var busy := 0
	for e in enemies:
		if not e.dead and float(e.get_meta("windup", 0.0)) > 0.0:
			busy += 1
	if busy >= MAX_WINDUP:
		return
	var ready: Array[Node2D] = []
	for e in enemies:
		if e.dead or e.knocked or e.stun > 0.0 or int(e.get_meta("slot", -1)) < 0 or e.attack_cd > 0.0:
			continue
		if float(e.get_meta("windup", 0.0)) > 0.0:
			continue
		# право удара — по факту «в зоне», а не по точному достижению точки:
		# разведение и движение героя не дают встать в точку с точностью до 3 px
		if absf(player.position.x - e.position.x) > REACH_X or absf(player.position.y - e.position.y) > REACH_Y:
			continue
		if not e.has_meta("arrived_at"):
			e.set_meta("arrived_at", Time.get_ticks_msec())
		ready.append(e)
	if ready.is_empty():
		return
	ready.sort_custom(func(x, y): return int(x.get_meta("arrived_at", 0)) < int(y.get_meta("arrived_at", 0)))
	# Не бьём сразу: даём герою окно уйти из зоны и запускаем замах.
	var striker: Node2D = ready[0]
	striker.set_meta("windup", randf_range(WINDUP_MIN, WINDUP_MAX))
	# пока идёт пауза перед ударом, враг отводит когти: замах видно, а не «телепорт» в удар
	striker.set_state("z_ready")
	strike_lock = STRIKE_GAP

# Удар в конце замаха: если герой успел выйти из зоны — это промах (#001).
func _enemy_strike(e: Node2D) -> void:
	# замах закончился: из позы замаха выходим всегда
	if e.state == "z_ready":
		e.set_state("idle")
	if player.dead or e.dead or e.stun > 0.0 or e.knocked:
		return
	# Зомби ДОВОДИТ удар до конца, даже если герой увернулся: видно сам рывок и
	# когти, а не «замах -> мгновенно стойка». Урон при этом не проходит.
	if not e.try_attack():
		return
	attacker = e
	strike_lock = STRIKE_GAP
	if player.invuln > 0.0:
		return
	if absf(player.position.x - e.position.x) > REACH_X or absf(player.position.y - e.position.y) > REACH_Y:
		return
	_spawn_fx(player.position)
	Sfx.play_var("hit", -2.0, 0.12)   # попадание по герою — глуше и ниже
	player.take_hit(ZOMBIE_DAMAGE, int(signf(player.position.x - e.position.x)))

func _slot_taken(slot: int, except: Node2D) -> bool:
	for e in enemies:
		if e == except or e.dead:
			continue
		if int(e.get_meta("slot", -1)) == slot:
			return true
	return false

func _claim_slot(e: Node2D) -> int:
	# сначала места на своей стороне, потом на противоположной — чтобы не идти сквозь героя
	# 0,1 — левая сторона; 2,3 — правая. Сначала свои места, потом чужие.
	var own: int
	if player.state == "punch1" or player.state == "punch2":
		# герой замахнулся: враг обходит и встаёт со стороны спины (#003)
		own = 0 if player.facing > 0 else 1
	else:
		own = 1 if e.position.x >= player.position.x else 0
	var other: int = 1 - own
	for s in [own * 2, own * 2 + 1, other * 2, other * 2 + 1]:
		if not _slot_taken(int(s), e):
			return int(s)
	return -1

func _slot_pos(e: Node2D, slot: int) -> Vector2:
	if slot < 0:
		# места нет: ждёт в стороне, пока один из четверых не освободится
		var side: float = signf(e.position.x - player.position.x)
		if side == 0.0:
			side = 1.0
		return Vector2(
			player.position.x + side * WAIT_DIST,
			clampf(player.position.y, ARENA_TOP, ARENA_BOTTOM)
		)
	var off: Vector2 = SLOTS[slot]
	return Vector2(
		clampf(player.position.x + off.x, ARENA_MIN_X, ARENA_MAX_X),
		clampf(player.position.y + off.y, ARENA_TOP, ARENA_BOTTOM)
	)

func _resolve_overlap(a: Node2D, b: Node2D, rx: float, ry: float, share_a := 0.55, share_b := 0.45) -> void:
	# эллипс вокруг корпуса: тела расходятся по той оси, где до края ближе
	var d := b.position - a.position
	var nx := d.x / rx
	var ny := d.y / ry
	if nx * nx + ny * ny >= 1.0:
		return
	var push_x: float = (1.0 - absf(nx)) * rx
	var push_y: float = (1.0 - absf(ny)) * ry
	if push_x <= push_y:
		var dir: float = signf(d.x) if d.x != 0.0 else 1.0
		a.position.x -= dir * push_x * share_a
		b.position.x += dir * push_x * share_b
	else:
		var diry: float = signf(d.y) if d.y != 0.0 else 1.0
		a.position.y -= diry * push_y * share_a
		b.position.y += diry * push_y * share_b

func _spawn_fx(at: Vector2) -> void:
	var fx: Node2D = HitFx.new()
	fx.position = Vector2(at.x, at.y - 70.0)
	# только внутри world: иначе у вспышки отдельная очередь рисования
	world.add_child(fx)

func _update_waves(delta: float) -> void:
	# Живые подходят партиями: волна не вываливается толпой, а подкармливается
	# по одному, как только освободилось место. Иначе пять тел сливаются в кашу.
	_trickle_spawn()
	if wave >= WAVES.size():
		return
	if wave_timer > 0.0:
		wave_timer -= delta
		if wave_timer <= 0.0 and pending_spawn == 0 and enemies.is_empty():
			_spawn_wave()
		return
	if pending_spawn == 0 and enemies.is_empty():
		wave_timer = WAVE_DELAY

func _alive_count() -> int:
	var n := 0
	for e in enemies:
		if not e.dead:
			n += 1
	return n

func _trickle_spawn() -> void:
	while pending_spawn > 0 and _alive_count() < MAX_ACTIVE:
		_spawn_one(wave_slot % 4)
		wave_slot += 1
		pending_spawn -= 1

func _spawn_wave() -> void:
	pending_spawn = int(WAVES[wave][0])
	wave += 1
	_trickle_spawn()

func _spawn_one(slot: int) -> void:
	var e: Node2D = Fighter.new()
	# каждый второй зомби — с открытым мозгом (кадры assets/zombie_brain)
	e.configure(82.0 + float(slot) * 5.0, ZOMBIE_HP, ZOMBIE_DAMAGE, true, slot % 2 == 0)
	e.atk_cooldown = ZOMBIE_ATK_CD
	# Спавн строго за кадром с противоположной стороны: враг входит в кадр
	# целиком и пешком идёт к герою. Раньше он появлялся посреди улицы.
	# Волна приходит с двух сторон по очереди: тогда вокруг героя занимаются
	# все четыре места, а не одна колонна справа.
	var from_right: bool = slot % 2 == 0
	var edge: float = cam.position.x + 480.0 if from_right else cam.position.x - 480.0
	var sx: float = edge + 90.0 if from_right else edge - 90.0
	e.position = Vector2(sx, ARENA_TOP + 50.0 + float(slot % 4) * 36.0)
	e.z_index = int(e.position.y)
	e.set_meta("slot", -1)
	e.set_meta("arrived", false)
	# тот же родитель, что у героя, — иначе глубина не работает и враг всегда поверх
	if world:
		world.add_child(e)
	else:
		add_child(e)
	enemies.append(e)

func _respread_enemies() -> void:
	for i in range(enemies.size()):
		if not enemies[i].dead:
			enemies[i].set_meta("slot", i)

func _cleanup_enemies() -> void:
	var alive: Array[Node2D] = []
	for e in enemies:
		# убираем сразу после затухания: иначе труп держит список непустым
		# и следующая волна не появляется никогда
		if e.dead and e.t > 0.6 and is_instance_valid(e):
			e.queue_free()
		elif not e.dead:
			alive.append(e)
	enemies = alive

func _update_hud() -> void:
	bar_fill.size.x = maxf(2.0, 248.0 * float(player.hp) / float(player.max_hp))
	bar_fill.color = Color(0.85, 0.2, 0.2) if player.hp > player.max_hp * 0.35 else Color(0.95, 0.55, 0.1)
	wave_label.text = "ВОЛНА %d / %d" % [clampi(maxi(wave, 1), 1, WAVES.size()), WAVES.size()]
	time_label.text = "ВРЕМЯ %05.1f" % elapsed
	hits_label.text = "УДАРОВ %d" % hits if hits > 0 else ""
	if wave_timer > 0.0 and wave < WAVES.size():
		msg_label.text = "ВОЛНА %d" % (wave + 1)
		msg_label.modulate = Color(1, 1, 1, clampf(wave_timer / WAVE_DELAY, 0.65, 1.0))
	elif not finished:
		msg_label.text = ""

func _finish(text: String) -> void:
	finished = true
	result = text
	msg_label.modulate = Color(1, 0.9, 0.3)
	hits_label.visible = false # счётчик убираем, чтобы не наезжал на итоговый текст
	msg_label.text = text + "  (R — заново)"
	# выше линии боя: иначе финальный текст наезжает на героя
	msg_label.position = Vector2(250, 120)