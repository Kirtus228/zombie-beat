extends SceneTree
func _init() -> void:
	var F = load("res://scripts/fighter.gd")
	print("Z_ATK_FRAMES=", F.Z_ATK_FRAMES)
	print("Z_READY=", F.Z_READY_FRAME)
	var e = F.new()
	e.configure(82.0, 90, 5, true, true)
	var sf = e._build_frames()
	print("z_ready frames=", sf.get_frame_count("z_ready"))
	var p: String = e.frames_dir + "/punch2_1.png"
	print("path=", p, " exists=", ResourceLoader.exists(p))
	var tex = load(p)
	print("tex=", tex)
	quit(0)
