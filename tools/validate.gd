extends SceneTree
## Headless validation: loads every script in the project and reports failures.
## Run: godot --headless --script tools/validate.gd
## CI runs this before the Android export so a syntax error never reaches a build.

func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	files.append("res://tools/validate.gd")
	var failures := 0
	for path in files:
		var res: Variant = load(path)
		if res == null:
			push_error("FAILED TO LOAD: " + path)
			print("FAIL  ", path)
			failures += 1
		else:
			print("OK    ", path)
	print("---")
	print("scripts checked: %d, failures: %d" % [files.size(), failures])
	if failures > 0:
		quit(1)
	else:
		print("VALIDATION PASSED")
		quit(0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			_collect(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
