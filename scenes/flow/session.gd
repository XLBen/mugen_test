class_name Session
extends RefCounted
## 跨场景的对局设置（标题 → 选人 → 对局）。用静态变量保存，不需要 autoload；直接运行训练场景时保持默认值。

enum Mode { TRAINING, VS_CPU, VS_2P }

const MODE_NAMES := ["训练模式", "对战电脑", "双人对战"]
const CPU_LEVELS := 8

static var mode: int = Mode.TRAINING
static var from_menu := false ## 是否经过选人画面（否则训练场景按自己的默认值开局）
static var picks: Array[int] = [0, 1] ## Roster.load_all() 里的下标
static var cpu_level := 4 ## 1–8


static func reset() -> void:
	mode = Mode.TRAINING
	from_menu = false
	picks = [0, 1]
	cpu_level = 4
