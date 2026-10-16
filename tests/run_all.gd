extends SceneTree
## 运行 tests/ 下所有 test_*.gd 中的 test_* 方法。
## godot --headless --path . -s res://tests/run_all.gd [-- 文件名过滤]
## 退出码 0 = 全部通过。


func _initialize() -> void:
	var filter := ""
	if OS.get_cmdline_user_args().size() > 0:
		filter = OS.get_cmdline_user_args()[0]
	var total_failures := 0
	var total_tests := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not file.begins_with("test_") or not file.ends_with(".gd") or file == "test_case.gd":
			continue
		if filter != "" and not file.contains(filter):
			continue
		print(file)
		var script: GDScript = load("res://tests/" + file)
		for m in script.get_script_method_list():
			var method_name: String = m.name
			if not method_name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.current = method_name
			t.call(method_name)
			total_tests += 1
			total_failures += t.failures
			print("  %s %s" % ["ok  " if t.failures == 0 else "FAIL", method_name])
	print("\n%s: %d tests, %d failures" % ["PASS" if total_failures == 0 else "FAIL", total_tests, total_failures])
	quit(1 if total_failures > 0 else 0)
