extends SceneTree
# Проверка: музыка реально запускается из main.tscn и зациклена.

func _init() -> void:
	print("exists=", ResourceLoader.exists("res://assets/music/loop.ogg"), " file=", FileAccess.file_exists("res://assets/music/loop.ogg"))
	var node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	for i in 8:
		await process_frame
	for c in node.get_children():
		if c is AudioStreamPlayer:
			print("player found: playing=", c.playing, " stream=", c.stream, " stream_loop=", c.stream.loop if c.stream else null, " len=", c.stream.get_length() if c.stream else -1)
	var ok := false
	for c in node.get_children():
		if c is AudioStreamPlayer and c.stream != null:
			ok = c.playing
	print("fails=", 0 if ok else 1)
	quit()
