class_name SpriteSet
extends RefCounted
## 一个角色一套配色的精灵动画，读取 tools/spritegen 生成的 anims.json + PNG。
## 选帧完全由逻辑帧号决定（逻辑驱动显示），不使用 AnimationPlayer。

var anchor := Vector2.ZERO
var scale := 1
var _data := {} ## name -> AnimData（时序，与仿真共用选帧规则）
var _anims := {} ## name -> { loop: bool, anchor: Vector2, textures: Array[Texture2D], ends: Array[int] }


static func load_from(dir: String, palette: int) -> SpriteSet:
	var meta_text := FileAccess.get_file_as_string(dir.path_join("anims.json"))
	if meta_text.is_empty():
		return null
	var meta: Dictionary = JSON.parse_string(meta_text)
	var sprites := SpriteSet.new()
	sprites.anchor = Vector2(meta.anchor[0], meta.anchor[1])
	sprites.scale = int(meta.scale)
	var pal_dir := dir.path_join("pal%d" % clampi(palette, 0, int(meta.palettes) - 1))
	for anim_name: String in meta.anims:
		var anim: Dictionary = meta.anims[anim_name]
		var textures: Array[Texture2D] = []
		var ends: Array[int] = []
		var t := 0
		for frame: Array in anim.frames:
			textures.append(load(pal_dir.path_join(frame[0] + ".png")))
			t += int(frame[1])
			ends.append(t)
		var anchor := sprites.anchor
		if anim.has("anchor"):
			anchor = Vector2(anim.anchor[0], anim.anchor[1])
		sprites._data[anim_name] = AnimData.from_meta(anim)
		sprites._anims[anim_name] = {"loop": anim.loop, "anchor": anchor, "textures": textures, "ends": ends}
	return sprites


func data(anim_name: String) -> AnimData:
	return _data[anim_name]


func has(anim_name: String) -> bool:
	return _anims.has(anim_name)


## 动画自己的锚点（特效类动画以中心为锚点，角色动画以脚底为锚点）。
func anchor_of(anim_name: String) -> Vector2:
	return _anims[anim_name].anchor if _anims.has(anim_name) else anchor


## 动画开始后第 t 帧应显示的贴图；非循环动画停在最后一帧。
func frame_at(anim_name: String, t: int) -> Texture2D:
	var anim: Dictionary = _anims.get(anim_name, _anims.get("idle"))
	var ends: Array[int] = anim.ends
	var total := ends[-1]
	t = t % total if anim.loop else mini(t, total - 1)
	for i in ends.size():
		if t < ends[i]:
			return anim.textures[i]
	return anim.textures[-1]


func frame_count(anim_name: String) -> int:
	return _anims[anim_name].textures.size() if _anims.has(anim_name) else 0


## 按索引直接取帧（空中动画按速度选帧用）。
func frame_index(anim_name: String, i: int) -> Texture2D:
	var textures: Array[Texture2D] = _anims[anim_name].textures
	return textures[clampi(i, 0, textures.size() - 1)]
