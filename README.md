# mugenlike

一个用 Godot 4.7 写的可扩展 2D 格斗游戏底座（白模）。参考《街头霸王》《罪恶装备》《拳皇》的共通结构，
逻辑层确定性、整数运算、可存读档（为回滚联网预留），规则差异做成可替换模块。第一套参考规则是街霸风 6 键。

设计分析见 [docs/fighting-core-analysis.md](docs/fighting-core-analysis.md)。

## 运行
用 Godot 4.7 打开工程，运行主场景 `scenes/training.tscn`。

| 操作 | P1 | P2 |
|---|---|---|
| 移动 | WASD | 方向键 |
| LP MP HP | U I O | 小键盘 7 8 9 |
| LK MK HK | J K L | 小键盘 4 5 6 |

F1 判定框 · F2 存档 · F3 读档 · F4 暂停 · F5 单帧步进 · F6 重置

## 测试
```bash
godot --headless --path . -s res://tests/determinism_test.gd
```

## 目录
- `core/` 纯逻辑仿真（不依赖场景树）
- `view/` 表现层，只读取仿真状态
- `input/` 本机键盘/手柄输入
- `characters/` `stages/` 角色与舞台数据
- `tests/` 无头测试
