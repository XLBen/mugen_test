class_name SimConst
## 仿真层全局常量。逻辑层只使用整数：1 像素 = UNITS_PER_PX 个逻辑单位。

const UNITS_PER_PX := 100
const FPS := 60

## 逻辑屏幕宽度（像素）。两名角色的推挤盒必须同时落在一屏之内。
const SCREEN_WIDTH_PX := 1280
const SCREEN_HALF_W := SCREEN_WIDTH_PX * UNITS_PER_PX / 2

## 摄像机墙相对屏幕边缘向内收的距离。
const CAMERA_WALL_MARGIN := 24 * UNITS_PER_PX


static func px(units: int) -> float:
	return float(units) / UNITS_PER_PX
