# 进度记录

## 2026-10-16
- **M1**：确定性仿真循环、整数物理、存读档、白模渲染、走/蹲/跳/推挤/摄像机墙。
- **像素占位素材**：`tools/spritegen/` 程序化骨骼 + 部件绘制，赛璐璐三阶阴影 + 有色描边。
  三个原创角色 Kagura / Volk / Mio，各两套配色；目前有 idle / walk_f / walk_b / crouch / prejump / jump / land。
  游戏内 2× 最近邻放大，F7 切换精灵/白模，F8/F9 切换角色。
- `tools/screenshot.gd`：用脚本输入推进仿真后截图，用于自查画面。
