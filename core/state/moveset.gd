class_name Moveset
extends RefCounted
## 一个角色的全部状态 + 出招表 + 飞行道具。由"公共状态（规则模块）+ 角色招式"合并构建。
## 状态在运行时用整数索引表示（可哈希、可存档），名字只在构建和调试时使用。

var states: Array[StateDef] = []
var index := {} ## name -> int
var commands: Array[Command] = []
var projectiles: Array[ProjectileDef] = []
var projectile_index := {} ## name -> int

static var _cache := {} ## 数据脚本路径 + 精灵目录 -> Moveset（静态数据，可共享）


static func for_def(def: FighterDef) -> Moveset:
	var key := def.moveset.resource_path + "|" + def.sprite_dir
	if not _cache.has(key):
		var m := build(CommonStates.states(), def.moveset.new().data())
		if def.sprite_dir != "":
			m.apply_anim_boxes(AnimData.load_library(def.sprite_dir))
		_cache[key] = m
	return _cache[key]


static func build(common: Dictionary, character: Dictionary) -> Moveset:
	var m := Moveset.new()
	var all := common.duplicate()
	all.merge(character.get("states", {}), true)
	for state_name: String in all:
		m.index[state_name] = m.states.size()
		m.states.append(StateDef.build(state_name, all[state_name]))
	for c: Dictionary in character.get("commands", []):
		m.commands.append(Command.build(c))
	for p_name: String in character.get("projectiles", {}):
		m.projectile_index[p_name] = m.projectiles.size()
		m.projectiles.append(ProjectileDef.build(p_name, character.projectiles[p_name]))
	return m


## 画面与判定同源：状态的动画如果带逐帧判定盒（生成器导出或 MUGEN Clsn 导入），
## 受击盒按动画帧取；攻击判定的形状换成动画持续帧的攻击盒（时机、伤害等帧数据仍以招式表为准）。
## 投判定和推挤盒属于规则数据，不受影响。
func apply_anim_boxes(lib: Dictionary) -> void:
	for s in states:
		if not lib.has(s.anim):
			continue
		var anim: AnimData = lib[s.anim]
		if not anim.has_boxes():
			continue
		s.anim_data = anim
		if s.anim_dir:
			for k in 3:
				s.anim_alts[k] = lib.get(AnimClock.anim_name(s, k - 1), anim)
		s.hurtboxes = []
		for h: Dictionary in s.hitboxes:
			var hits: Array = anim.hit[AnimClock.frame(s, anim, h.from, 0)]
			if not hits.is_empty():
				h.boxes = hits
		s.reach = 0
		for h: Dictionary in s.hitboxes:
			for b: PackedInt32Array in h.boxes:
				s.reach = maxi(s.reach, b[0] + b[2])


func id(state_name: String) -> int:
	assert(index.has(state_name), "unknown state " + state_name)
	return index[state_name]
