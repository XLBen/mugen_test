class_name Moveset
extends RefCounted
## 一个角色的全部状态 + 出招表 + 飞行道具。由"公共状态（规则模块）+ 角色招式"合并构建。
## 状态在运行时用整数索引表示（可哈希、可存档），名字只在构建和调试时使用。

var states: Array[StateDef] = []
var index := {} ## name -> int
var commands: Array[Command] = []
var projectiles: Array[ProjectileDef] = []
var projectile_index := {} ## name -> int

static var _cache := {} ## 数据脚本路径 -> Moveset（静态数据，可共享）


static func for_def(def: FighterDef) -> Moveset:
	var key := def.moveset.resource_path
	if not _cache.has(key):
		_cache[key] = build(CommonStates.states(), def.moveset.new().data())
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


func id(state_name: String) -> int:
	assert(index.has(state_name), "unknown state " + state_name)
	return index[state_name]
