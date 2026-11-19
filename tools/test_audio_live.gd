extends SceneTree
# Живая проверка звука: стоны толпы идут сами, удар героя озвучен.
# Сцена настоящая, без заглушек.

func _init() -> void:
	var node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	await process_frame

	# 1) стон из толпы: таймер сам должен выстрелить за 9 секунд
	var before: int = Sfx.plays
	await create_timer(9.0).timeout
	var groan_ok: bool = Sfx.plays > before
	print("groans=", Sfx.plays - before)

	# 2) удар героя по зомби: свист + попадание + рык раненого
	var e = (load("res://scripts/fighter.gd") as GDScript).new()
	e.configure(90.0, 90, 5, true)
	e.position = node.player.position + Vector2(20.0, 0.0)
	node.world.add_child(e)
	node.enemies.append(e)
	var b2: int = Sfx.plays
	var swung: bool = node.player.try_attack()   # свист кулака
	node._resolve_player_hit()                   # попадание + рык раненого
	var hit_ok: bool = swung and Sfx.plays - b2 >= 3
	print("hit_plays=", Sfx.plays - b2, " hits=", node.last_hit_n)
	print("fails=", 0 if (groan_ok and hit_ok) else 1)
	quit()
