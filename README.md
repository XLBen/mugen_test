# mugenlike

一个用 Godot 4.7 写的可扩展 2D 格斗游戏底座（白模）。参考《街头霸王》《罪恶装备》《拳皇》的共通结构，
逻辑层确定性、整数运算、可存读档（为回滚联网预留），规则差异做成可替换模块。第一套参考规则是街霸风 6 键。

设计分析见 [docs/fighting-core-analysis.md](docs/fighting-core-analysis.md)，进度记录见 [docs/progress.md](docs/progress.md)。

## 占位角色
三个原创角色（Kagura / Volk / Mio）的像素精灵由 `tools/spritegen/` 程序化生成（Python + Pillow），
每个角色两套配色，可随时重新生成：`python3 tools/spritegen/spritegen.py`

![characters](docs/img/characters.png)

## 运行
用 Godot 4.7 打开工程，运行主场景 `scenes/training.tscn`。

| 操作 | P1 | P2 |
|---|---|---|
| 移动 | WASD | 方向键 |
| LP MP HP | U I O | 小键盘 7 8 9 |
| LK MK HK | J K L | 小键盘 4 5 6 |

F1 判定框 · F2 存档 · F3 读档 · F4 暂停 · F5 单帧步进 · F6 重置 · F7 精灵/白模 · F8/F9 切换角色

## 测试
```bash
godot --headless --path . -s res://tests/run_all.gd
```
`tests/test_*.gd` 中所有 `test_` 开头的方法都会被执行；可加 `-- combat` 只跑文件名包含 combat 的测试。

## 目录
- `core/` 纯逻辑仿真（不依赖场景树）
- `view/` 表现层，只读取仿真状态
- `input/` 本机键盘/手柄输入
- `characters/` `stages/` 角色与舞台数据
- `rulesets/sf_like/` 街霸风规则模块（公共状态：移动、受击、防御、倒地、被投）
- `characters/shared/` 共用招式表（帧数据）
- `tools/` 精灵生成器、截图工具、输入脚本
- `tests/` 无头测试
