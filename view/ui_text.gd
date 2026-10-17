class_name UiText
## 画面上显示用的中文名称（状态名、假人设置）。逻辑里仍用英文标识符，这里只做显示。

const STATES := {
	"stand": "站立", "crouch": "蹲", "walk_f": "前走", "walk_b": "后退", "prejump": "起跳", "air": "空中",
	"landing": "落地", "landing_long": "落地硬直", "dash_f": "前冲", "dash_b": "后撤步",
	"guard_stand": "防御姿势", "guard_crouch": "蹲防姿势", "block_stand": "站防", "block_crouch": "蹲防",
	"hit_stand": "站立受击", "hit_crouch": "蹲受击", "hit_air": "浮空受击", "land_recover": "受身",
	"knockdown": "倒地", "wakeup": "起身", "ko": "KO", "thrown": "被投", "throw_tech": "拆投",
	"throw": "投", "throw_hit": "投（命中）", "wakeup_back": "后滚起身", "crumple": "崩溃", "wall_splat": "贴墙",
	"dizzy": "眩晕",
}
const DUMMY_MODES := ["玩家操作", "站立", "蹲下", "跳跃", "录制中", "回放"]
const DUMMY_GUARD := ["关", "全部"]


## 状态的显示名：公共状态用中文，普攻写成 5LP / 2MK / j.HP，必杀等保留招式表里的名字。
static func state(state_name: String) -> String:
	if STATES.has(state_name):
		return STATES[state_name]
	if state_name.length() == 3 and state_name[0] in "25" and state_name.substr(1) in ["lp", "mp", "hp", "lk", "mk", "hk"]:
		return state_name.to_upper()
	if state_name.begins_with("j_") and state_name.length() == 4:
		return "j." + state_name.substr(2).to_upper()
	return state_name
