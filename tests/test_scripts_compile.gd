extends TestCase
## 确保表现层与工具脚本能编译（无头测试不会执行绘制代码，但必须能加载）。

const SCRIPTS := [
	"res://scenes/training.gd", "res://view/match_view.gd", "res://view/sprite_set.gd",
	"res://input/local_input.gd", "res://tools/screenshot.gd", "res://tools/input_script.gd",
]


func test_scripts_compile() -> void:
	for path: String in SCRIPTS:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "script compiles: " + path)


func test_training_scene_instantiates() -> void:
	var scene: Node = load("res://scenes/training.tscn").instantiate()
	check(scene.get_script() != null, "training scene has its script")
	check(scene.get_node("MatchView").get_script() != null, "MatchView has its script")
	scene.free()


func test_sprite_sets_load() -> void:
	for id in ["kagura", "volk", "mio"]:
		for palette in 2:
			var sprites := SpriteSet.load_from("res://characters/%s/sprites" % id, palette)
			check(sprites != null and sprites.has("idle") and sprites.frame_at("idle", 0) != null,
				"%s palette %d loads" % [id, palette])
