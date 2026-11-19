extends SceneTree
# Проверка: звуки грузятся и реально играют (пул живёт без автозагрузки).

func _init() -> void:
	await process_frame   # в _init() главного цикла ещё нет — ждём первый кадр
	for key in Sfx.PATHS:
		Sfx.play(key)
	for i in 6:
		await process_frame
	var st: Dictionary = Sfx.info()
	print("info=", st)
	var ok: bool = st.get("streams", 0) == Sfx.PATHS.size() and int(st.get("playing", 0)) > 0
	print("fails=", 0 if ok else 1)
	quit()
