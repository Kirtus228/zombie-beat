extends Node2D
# Боец на спрайтах пака Jampa (CC0). Кадры нарезаны из листа в assets/jampa/<набор>/.

const Shadow := preload("res://scripts/shadow.gd")
# кадры из norm_*: арт отцентрован и выровнен по линии ступней (tools/normalize_frames.gd)
const FRAME_DIR := "res://assets/jampa/norm_"
# свой герой по фото Кирилла: перекрашенные кадры пака (tools/recolor_hero.ps1)
const HERO_DIR := "res://assets/hero/"
# зомби: перекрашенные кадры пака (tools/recolor_zombie.ps1) — та же геометрия,
# поэтому анимации и хитбоксы не меняются
const ZOMBIE_DIR := "res://assets/zombie/"
# каждый второй зомби — с открытым мозгом (tools/brainify3.ps1): красное только до глаз
const ZOMBIE_BRAIN_DIR := "res://assets/zombie_brain/"
const SPRITE_SCALE := 0.62
const CELL_FEET := 107.5 # от центра кадра до ступней, px
const PUNCH_HOLD := 0.34
# Удар зомби — сверху вниз, когтями, а не кулаком вперёд как у героя-боксёра.
# Только кадры пака: рука с раскрытыми пальцами вверху (punch1_0), свал корпусом
# вниз с разведёнными когтями (falling), возврат в стойку (punch2_1).
# Кулака в этой цепочке нет ни в одном кадре.
# Сверху-вниз добавляет не только кадр: корпус отклоняется НАЗАД на замахе и
# падает ВПЕРЁД на ударе (PITCH_*), поэтому рука идёт дугой сверху.
const Z_ATK_FRAMES: Array[String] = ["punch1_0", "punch1_0", "punch2_1", "punch2_1", "punch2_1", "punch2_1"]
const Z_CONTACT_FRAME := "punch2_1"  # кадр, на котором когти достают цель
const Z_ATK_FPS := 10.0
const Z_ATK_HOLD := 0.6        # длина всей анимации удара, с
const Z_CONTACT_T := 0.2       # момент касания внутри удара: на нём включается урон
const Z_LUNGE := 22.0          # рывок корпуса к цели, px
const Z_PITCH_BACK := 8.0      # наклон назад на замахе, градусы
const Z_PITCH_FRONT := 11.0    # свал вперёд на ударе, градусы
const Z_READY_FRAME := "punch1_0"
const Z_WALK_FPS := 6.5             # походка зомби медленнее человеческой (у героя 12)
const JUMP_TIME := 0.52    # прыжок: время в воздухе
const JUMP_H := 58.0       # высота дуги прыжка, px
# серия ударов: пять подряд роняют врага, недобитая серия оставляет оглушение
const COMBO_WINDOW := 1.0   # сколько ждём следующий удар, чтобы серия продолжилась
const KILL_COMBO := 5       # столько ударов подряд — цель падает
const STUN_TIME := 1.5      # оглушение после одиночного удара
const KNOCK_TIME := 1.2     # сколько лежит после падения, потом встаёт
const GETUP_INVULN := 0.7   # сразу после подъёма его нельзя снова ронять

var speed := 110.0
var hp := 100
var max_hp := 100
var damage := 10
var is_enemy := false
var atk_cooldown := 0.34
var facing := 1
var state := "idle"
var t := 0.0
var attack_cd := 0.0
var invuln := 0.0
var flash := 0.0
var moving := false
var idle_timer := 0.0
var dead := false
var body: AnimatedSprite2D
var shadow: Node2D
var sheet_name := "guy1"
var frames_dir := ""
var combo := 0          # сколько ударов подряд получил
var combo_timer := 0.0  # через сколько серия сбрасывается
var stun := 0.0         # оглушение: не двигается и не бьёт
var knocked := false    # лежит после серии: не бьёт, его не бьют, встанет
var knock_timer := 0.0
var airborne := false   # в прыжке
var air_t := 0.0
var shamble_t := 0.0    # фаза походки зомби
var stagger := 0.0      # запинка: шаг замирает на долю секунды

func _ready() -> void:
	shadow = Shadow.new()
	shadow.z_index = -2
	add_child(shadow)
	frames_dir = _dir_for(sheet_name)
	body = AnimatedSprite2D.new()
	body.sprite_frames = _build_frames()
	body.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	body.centered = true
	# Точка вращения — СТУПНИ, а не центр кадра: иначе при наклоне корпуса
	# (сутулость, замах, свал в ударе) ноги уезжали с линии земли и зомби
	# выглядел так, будто бьёт в воздухе / подпрыгивает (замечание Кирилла 21.11).
	# Смещение offset поднимает текстуру так же, как раньше, но крутим вокруг ног.
	body.offset = Vector2(0, -CELL_FEET * SPRITE_SCALE)
	body.position = Vector2.ZERO
	add_child(body)
	_sync()

# папка кадров: герою — своя, если она есть; иначе кадры пака (откат)
func _dir_for(sheet: String) -> String:
	if sheet == "guy1" and ResourceLoader.exists(HERO_DIR + "idle.png"):
		return HERO_DIR
	if sheet == "guy2" and ResourceLoader.exists(ZOMBIE_DIR + "idle.png"):
		return ZOMBIE_DIR
	if sheet == "guy3" and ResourceLoader.exists(ZOMBIE_BRAIN_DIR + "idle.png"):
		return ZOMBIE_BRAIN_DIR
	return FRAME_DIR + sheet

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var walking: Array[String] = []
	for i in range(9):
		# walk_1 и walk_2 нарисованы на 45 px выше остальных кадров — из-за них
		# персонаж «подпрыгивает» при смене кадра; в цикл не берём
		if i == 1 or i == 2:
			continue
		walking.append("walk_%d" % i)
	_add(sf, "idle", ["idle"], 4.0, true)
	# у зомби шаг заметно медленнее: тянет ноги
	_add(sf, "walk", walking, Z_WALK_FPS if is_enemy else 12.0, true)
	if not is_enemy:
		# медленнее и с двумя проходами по кадрам: успевает читаться кадр с вытянутой рукой
		_add(sf, "punch1", ["punch1_0", "punch1_1", "punch1_1", "punch1_1"], 10.0, false)
		_add(sf, "punch2", ["punch2_0", "punch2_1", "punch2_2", "punch2_2", "punch2_2"], 10.0, false)
	_add(sf, "hurt", ["falling"], 1.0, false)
	# прыжок и удар в прыжке: кадры пака (assets/jampa/guy1*/jump*.png), герою
	# они перекрашены tools/recolor_hero.ps1
	_add(sf, "jump", ["jump"], 1.0, false)
	_add(sf, "jumpkick", ["jumpkick"], 1.0, false)
	# удар зомби: не боксёрский прямой из пака, а рывок телом — сгорбился (falling),
	# кинулся (jump), добил когтями (punch2_1). Анимаций с человеческим прямым
	# кулаком у врага в наборе НЕТ вообще (punch1/punch2 собираются только герою).
	if is_enemy:
		_add(sf, "z_atk", Z_ATK_FRAMES, Z_ATK_FPS, false)
		# замах: враг видимо отводит когти назад, пока идёт пауза перед ударом
		_add(sf, "z_ready", [Z_READY_FRAME], 1.0, false)
	# «лежит на земле»: отдельный кадр (tools/make_down_frame.ps1). Если его нет —
	# падаем на старый кадр падения, чтобы игра не осталась без позы
	_add(sf, "down", ["down"], 1.0, false)
	if sf.get_frame_count("down") == 0:
		sf.clear("down")
		_add(sf, "down", ["falling"], 1.0, false)
	return sf

func _add(sf: SpriteFrames, anim: String, files: Array[String], fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for f in files:
		var path := frames_dir + "/" + f + ".png"
		# часть кадров намеренно выброшена при нормализации — их просто пропускаем
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame(anim, tex)

func configure(sp: float, mhp: int, dmg: int, enemy: bool, brain := false) -> void:
	speed = sp
	max_hp = mhp
	hp = mhp
	damage = dmg
	is_enemy = enemy
	sheet_name = "guy3" if brain else ("guy2" if enemy else "guy1")
	frames_dir = _dir_for(sheet_name)
	if body:
		body.sprite_frames = _build_frames()
		body.play(state)

func set_state(name: String) -> void:
	if state == name:
		return
	state = name
	t = 0.0
	_sync()

func _sync() -> void:
	if body == null:
		return
	body.flip_h = facing < 0
	if body.sprite_frames.has_animation(state):
		body.play(state)

func _process(delta: float) -> void:
	t += delta
	if attack_cd > 0.0:
		attack_cd -= delta
	if invuln > 0.0:
		invuln -= delta
	if flash > 0.0:
		flash -= delta
	if stun > 0.0:
		stun -= delta
	if knocked:
		knock_timer -= delta
		if knock_timer <= 0.0:
			# встаёт: тот же запас HP, что был, и короткая неуязвимость
			knocked = false
			combo = 0
			invuln = GETUP_INVULN
			set_state("idle")
			z_index = int(position.y)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	# спрайт НИКОГДА не становится полупрозрачным: сквозь него просвечивал сосед
	# и казалось, что персонаж «пропал в текстурах». Реакция на удар — красная вспышка.
	if body:
		var a := 1.0
		if dead:
			# труп гаснет быстро: иначе полупрозрачное тело висит поверх героя
			a = clampf(1.0 - t * 1.6, 0.0, 1.0)
		body.modulate = Color(1.7, 0.6, 0.6, a) if flash > 0.0 else Color(1, 1, 1, a)
		# тень гаснет вместе с телом, иначе после смерти на асфальте остаются её эллипсы
		if shadow:
			shadow.modulate.a = a
	# прыжок: дуга вверх; пока в воздухе, удары зомби не достают (invuln = время прыжка)
	var lift := 0.0
	if airborne:
		air_t += delta
		lift = JUMP_H * sin(PI * clampf(air_t / JUMP_TIME, 0.0, 1.0))
		if air_t >= JUMP_TIME:
			airborne = false
			air_t = 0.0
			if state == "jump" or state == "jumpkick":
				set_state("idle")
	# походка зомби: шаг неровный (тянет одну ногу), корпус раскачивается,
	# раз в пару секунд запинается и замирает. Это и отличает его от героя.
	var sway := 0.0
	if body:
		if is_enemy and state == "walk":
			shamble_t += delta
			body.speed_scale = 0.55 + 0.45 * (1.0 + sin(shamble_t * 3.1)) * 0.5
			sway = sin(shamble_t * 2.2) * 2.2 + float(facing) * 1.8
			if stagger <= 0.0 and randf() < 0.5 * delta:
				stagger = randf_range(0.12, 0.30)
			if stagger > 0.0:
				stagger -= delta
				body.speed_scale = 0.0
		else:
			body.speed_scale = 1.0
		# Зомби сутулится и раскачивается: наклон вперёд + качание на каждом шаге.
		# Поза из кадров пака человеческая, но за счёт наклона и раскачки силуэт
		# читается как шарканье, а не как строевой шаг.
		if is_enemy:
			# удар: на замахе корпус откидывается назад, на свале падает вперёд —
			# рука идёт дугой сверху вниз, а не выносится вперёд
			if state == "z_ready":
				body.rotation = deg_to_rad(-Z_PITCH_BACK * float(facing))
			elif state == "z_atk":
				var k := clampf(t / Z_ATK_HOLD, 0.0, 1.0)
				var peak := Z_CONTACT_T / Z_ATK_HOLD
				var pitch := 0.0
				if k < peak:
					pitch = lerpf(-Z_PITCH_BACK, Z_PITCH_FRONT, smoothstep(0.0, peak, k))
				else:
					pitch = lerpf(Z_PITCH_FRONT, 0.0, smoothstep(peak, 1.0, k))
				body.rotation = deg_to_rad(pitch * float(facing))
			else:
				var rock := 4.0 * sin(shamble_t * 2.6) if state == "walk" else 0.0
				body.rotation = deg_to_rad((6.0 + rock) * float(facing))
		else:
			body.rotation = 0.0
	# рывок зомби вперёд: к моменту касания корпус уже у цели, потом возвращается
	# (ноги остаются на земле — вверх ничего не поднимается)
	var lunge := 0.0
	if state == "z_atk":
		var k := clampf(t / Z_ATK_HOLD, 0.0, 1.0)
		var reach := Z_CONTACT_T / Z_ATK_HOLD
		if k < reach:
			lunge = Z_LUNGE * smoothstep(0.0, reach, k)
		else:
			lunge = Z_LUNGE * (1.0 - smoothstep(reach, 1.0, k))
		lunge *= float(facing)
	if body:
		body.position = Vector2(lunge + sway, -lift)
	if state == "z_atk":
		if t > Z_ATK_HOLD:
			set_state("idle")
	elif (state == "punch1" or state == "punch2") and t > PUNCH_HOLD:
		set_state("idle")
	elif not airborne and state != "down":
		# гистерезис: в стойку только после 0.15 с покоя, иначе анимация мигает
		# «шаг ↔ стойка» каждый кадр и враг выглядит дёргающимся
		if moving:
			idle_timer = 0.0
		else:
			idle_timer += delta
			if state == "walk" and idle_timer > 0.15:
				set_state("idle")
		_sync()

func move_by(v: Vector2) -> void:
	if dead:
		return
	position += v
	if absf(v.x) > 0.01:
		facing = 1 if v.x > 0.0 else -1
	moving = v.length() > 0.01
	if state == "idle" and moving:
		set_state("walk")
	else:
		_sync()

# Прыжок: короткая дуга, в воздухе героя не достать. Кадры — из пака (jump),
# удар в воздухе — jumpkick.
func jump() -> bool:
	if dead or airborne or knocked or stun > 0.0:
		return false
	airborne = true
	air_t = 0.0
	invuln = maxf(invuln, JUMP_TIME)
	set_state("jump")
	return true

func try_attack() -> bool:
	if dead or attack_cd > 0.0:
		return false
	attack_cd = atk_cooldown
	if is_enemy:
		# зомби на замахе рычит и кидается корпусом, а не бьёт боксёрским прямым
		Sfx.play_var("z_attack", -2.0, 0.08)
		set_state("z_atk")
	else:
		Sfx.play_var("swing", 0.0, 0.08)
		set_state("jumpkick" if airborne else ("punch1" if randf() < 0.5 else "punch2"))
	t = 0.0
	return true

func take_hit(dmg: int, from_dir: int) -> void:
	# лежачего не бьют: он встанет сам с тем запасом HP, что остался
	if dead or knocked or invuln > 0.0:
		return
	hp -= dmg
	invuln = 0.5
	if is_enemy:
		Sfx.play_var("z_hurt", -2.0, 0.1)
	else:
		Sfx.play_var("player_hurt", 0.0, 0.06)
	position.x += float(from_dir) * 16.0
	combo += 1
	combo_timer = COMBO_WINDOW
	# враг падает только от серии из пяти подряд: «забить» его бесконечно нельзя.
	# Недобитая серия (1–4 удара) оставляет его в оглушении и урон не копится в смерть.
	if hp <= 0:
		# HP кончились — падает окончательно и уходит из боя
		hp = 0
		dead = true
		if is_enemy:
			Sfx.play_var("z_death", 0.0, 0.08)
		set_state("down")
		z_index = 1
		return
	if is_enemy and combo >= KILL_COMBO:
		# серия из пяти подряд: падение, но не смерть — встанет с тем, что осталось
		knocked = true
		knock_timer = KNOCK_TIME
		stun = 0.0
		flash = 0.15   # вспышка только на удар, лежит уже без красного
		set_state("down")
		z_index = 1
		return
	if is_enemy:
		stun = STUN_TIME
		flash = STUN_TIME
	else:
		flash = 0.14
	# в паке нет кадра «получил удар», а «falling» на полсекунды ломал позу