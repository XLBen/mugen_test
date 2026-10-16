extends TestCase
## 确保所有脚本都能编译（无头测试不会执行绘制代码，但必须能加载）。自动扫描整个工程。

const SKIP_DIRS := [".godot", ".git", "tools/spritegen"]


func test_all_scripts_compile() -> void:
	var paths := _scripts("res://")
	check(paths.size() > 20, "found project scripts (%d)" % paths.size())
	for path: String in paths:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "script compiles: " + path)


func test_training_scene_instantiates() -> void:
	var scene: Node = load("res://scenes/training.tscn").instantiate()
	check(scene.get_script() != null and (scene.get_script() as GDScript).can_instantiate(), "training scene script")
	for node_path in ["MatchView", "HUD/HudView"]:
		var node := scene.get_node(node_path)
		check(node.get_script() != null and (node.get_script() as GDScript).can_instantiate(), node_path + " script")
	scene.free()


func test_sprite_sets_load() -> void:
	for id in ["kagura", "volk", "mio"]:
		for palette in 2:
			var sprites := SpriteSet.load_from("res://characters/%s/sprites" % id, palette)
			check(sprites != null and sprites.has("idle") and sprites.frame_at("idle", 0) != null,
				"%s palette %d loads" % [id, palette])


func _scripts(dir: String) -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(dir):
		var full := dir.path_join(sub)
		if full.trim_prefix("res://") in SKIP_DIRS:
			continue
		out.append_array(_scripts(full))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out
