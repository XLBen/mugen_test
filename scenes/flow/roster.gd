class_name Roster
extends RefCounted
## 可选角色：有本地导入的 MUGEN 人物（local_assets/mugen/*/fighter.tres，不入库）时只用它们；
## 没有时（例如刚从仓库拉下来）退回内置的占位角色。

const BUILTIN: Array[String] = [
	"res://characters/kagura/kagura.tres",
	"res://characters/volk/volk.tres",
	"res://characters/mio/mio.tres",
	"res://characters/dummy/dummy.tres",
]
const LOCAL_ORDER := ["shiki", "kouma", "ciel"] ## 志贵、翽马、希尔在前，其余按名字排


static func load_all() -> Array[FighterDef]:
	var out := local_fighters()
	if out.is_empty():
		for path in BUILTIN:
			out.append(load(path))
	return out


static func local_fighters() -> Array[FighterDef]:
	var out: Array[FighterDef] = []
	var base := "res://local_assets/mugen"
	if not DirAccess.dir_exists_absolute(base):
		return out
	var dirs := Array(DirAccess.get_directories_at(base))
	dirs.sort_custom(func(a: String, b: String) -> bool:
		return _order(a) < _order(b) if _order(a) != _order(b) else a < b)
	for d: String in dirs:
		var path := base.path_join(d).path_join("fighter.tres")
		if not d.begins_with("_") and ResourceLoader.exists(path):
			var def: FighterDef = load(path)
			if def != null:
				out.append(def)
	return out


static func _order(dir_name: String) -> int:
	var i := LOCAL_ORDER.find(dir_name)
	return i if i >= 0 else 99
