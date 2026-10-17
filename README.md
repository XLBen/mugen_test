# mugenlike

一个用 Godot 4.7 写的可扩展 2D 格斗游戏底座（白模）。参考《街头霸王》《罪恶装备》《拳皇》的共通结构，
逻辑层确定性、整数运算、可存读档（为回滚联网预留），规则差异做成可替换模块。第一套参考规则是街霸风 6 键。

设计分析见 [docs/fighting-core-analysis.md](docs/fighting-core-analysis.md)，进度记录见 [docs/progress.md](docs/progress.md)。
对照 SF6 的差距与修改见 [docs/sf6-gap-review.md](docs/sf6-gap-review.md)。

## 占位角色
三个原创角色（Kagura / Volk / Mio）的像素精灵由 `tools/spritegen/` 程序化生成（Python + Pillow），
每个角色两套配色，可随时重新生成：`python3 tools/spritegen/spritegen.py`

![characters](docs/img/characters.png)

## 运行
用 Godot 4.7 打开工程，运行主场景（标题画面 `scenes/title.tscn`）：对战电脑 / 双人对战 / 训练模式 → 选人 → 开打。
对局中按 Esc（手柄 Start）打开暂停菜单（继续 / 重新开始 / 重新选人 / 回到标题），比赛结束后弹出结算菜单（再来一局 / 重新选人 / 回到标题）。
直接运行 `scenes/training.tscn` 就是训练模式。

| 操作 | P1 | P2 |
|---|---|---|
| 移动 | WASD | 方向键 |
| LP MP HP | U I O | 小键盘 7 8 9（没有小键盘：; ' \） |
| LK MK HK | J K L | 小键盘 4 5 6（没有小键盘：, . /） |
| 菜单确定 / 返回 | U / J（或 Enter / Esc） | 小键盘 7 / 4（或 ; / ,） |

Mac 上 F1–F12 默认是亮度、音量、播放等媒体键，所以每个功能键都有一个替代键（第二列），两个都能用。

| 键 | Mac 替代键 | 功能 |
|---|---|---|
| F1 | 6 | 判定框显示 / 隐藏，默认隐藏（蓝 受击 / 红 攻击 / 绿 投 / 黄 推挤） |
| F2 / F3 | [ / ] | 存档 / 读档（整场状态） |
| F4 / F5 | P / N | 暂停 / 暂停时单帧步进 |
| F6 / Shift+F6 | R / Shift+R | 重置到中央 / 重置到版边 |
| F7 | V | 精灵 ↔ 白模 |
| F8 / F9 | 8 / 9 | 切换 P1 / P2 角色 |
| F10 | 0 | 训练模式 ↔ 对战模式（三局两胜） |
| F11 | - | 资源常满（训练） |
| F12 | = | 调试面板（帧号、状态哈希、双方状态表） |
| Alt+Enter | | 全屏 / 窗口（窗口任意大小都按 16:9 等比缩放，多余部分黑边）。在编辑器的 Game 面板里内嵌运行时窗口由编辑器决定，要大窗口请在 Game 面板关掉 "Embed Game on Next Play" |
| 1 / 2 / 3 | | 假人模式（玩家/站/蹲/跳/录制/回放/电脑）/ 自动防御 / 录制↔回放 |
| 4 / 5 | | 连段挑战开关 / 下一条连段（Shift+5 上一条） |
| 7 | | 电脑演示当前连段（Shift+7 依次演示当前角色全部连段；再按 7 或按任意操作键停止） |

训练模式默认假人是"站立"，要用 P2 键盘操作请按 1 切到 player。

默认规则模板为街头霸王 6（见 [docs/decisions.md](docs/decisions.md)）。通用操作（面朝右）：LP+LK 投（4LP+LK 后投）· 66/44 冲刺 ·
两键同按 = OD 版必杀（2 格 Drive）· 超杀分三级：SA1 1 格（236236K / 236236P）、SA2 2 格（214214 + 键）、SA3 3 格（236236 + 另一种键），体力 25% 以下 SA3 变成 Critical Art。
Drive 系统：HP+HK = Drive Impact（1 格，发生 26，两次霸体，命中崩溃 / 角落贴墙，Burnout 的对手在墙边防住会眩晕）· 防御中 6HP+HK = Drive Reversal（2 格，无敌反击，不能打死）· MP+MK 按住 = Drive Parry（开 0.5 格、按住持续消耗，招架打击 / 道具 / DI，成功回 Drive；开招架 2 帧内被打 = 完美招架：对手停顿 30 帧、反击伤害减半；招架中被投 = 确反投）。

| 角色 | 定位 | 体格 | 招式 |
|---|---|---|---|
| Kagura | 速攻 | 走/冲最快、体型小 | 236K 裂空斩 · 214P 影步（穿身）· 623K 月轮（L/M/H）· 空中 214K 坠星（上段）· 236236K 千刃（SA1）· 214214K 月华（SA2）· 236236P 千刃·极（SA3）· 6MP 中段 · 目标连段 5MP>HP、5LK>MK |
| Volk | 投技 | 最慢、体型大 | 360P 钢铁粉碎（不可拆指令投，起跳预备中也能出）· 214P 野牛冲撞（霸体）· 623P 铁锤（L/M/H）· 236236P 西伯利亚坠落（SA1）· 214214P 重炮冲锋（SA2）· 236236K 冻土崩落（SA3）· 5HK 霸体 · 4HP 对空 · 目标连段 5MP>HK |
| Mio | 远程 | 后退快、普攻最长 | 236P 纸符 · 空中 236P 落符（斜下）· 214P 封印（设置物）· 623K 缎带旋（L/M/H）· 236236P 纸吹雪（SA1）· 214214P 缎带天舞（SA2）· 236236K 纸吹雪·终（SA3）· 6HK 远踢 · 目标连段 2MP>HP |
| dummy | 参考 | 标准 | 236P 波动 · 623P 升龙 · 214K 突进踢 · 5MP>HP（白模，测试基准） |

## 连段
每个角色设计了 5–6 条 SF6 式连段（`>` 目押 / 连打，`xx` 取消），训练模式按 4 打开连段挑战逐步练习。
按 7 让电脑操作 P1 打出当前连段（自动摆好距离、补满资源、布置确反场面），Shift+7 依次演示全部，用来检查连段的画面效果。
`tests/test_combo_routes.gd` 保证每条对所有对手（dummy、内置三人、本地导入的人物）都能连上，并且每一步都有至少 3 帧的输入窗口。

| 角色 | 连段 |
|---|---|
| Kagura / 志贵 | `2LK > 2LP > 5LP xx 236LK` · `5MP > 5HP xx 236HK` · `j.HK > 5HP xx 236HK`（深跳入）· `PC 5HP > 5MP xx 236HK`（确反对手重脚收招）· `5MP > 5HP xx 236MK xx 236236K` · `5MP > 5HP xx 236KK` |
| Volk / 翽马 | `5LP > 5LP xx 623P`* · `2MK xx 214P` · `j.HP > 5HP xx 214P` · `CH 5HP xx 623P`* · `5MP xx 214PP` |
| Mio / 希尔 | `2LP > 5LP xx 236LP` · `2MK xx 236HP` · `5LP > 5LP xx 623K`* · `j.HP > 5MP xx 236HP` · `5HP xx 236PP` · `5MP xx 236236P` |

\* 只对导入的人物成立（依赖月姬格斗动作的攻击判定；内置占位美术的升龙判定在头顶）。

## 导入月姬格斗（MUGEN）人物
可以把 MUGEN 人物的精灵和逐帧判定盒导入本地使用（素材不入库），见 [docs/mugen-import.md](docs/mugen-import.md)。

## 测试
```bash
godot --headless --path . -s res://tests/run_all.gd
```
`tests/test_*.gd` 中所有 `test_` 开头的方法都会被执行；可加 `-- combat` 只跑文件名包含 combat 的测试。
MUGEN 导入器的测试：`python3 -m unittest discover -s tools/mugen -p "test_*.py"`

## 目录
- `core/` 纯逻辑仿真（不依赖场景树）
- `view/` 表现层，只读取仿真状态
- `input/` 本机键盘/手柄输入
- `characters/` `stages/` 角色与舞台数据
- `rulesets/sf_like/` 街霸风规则模块（公共状态：移动、受击、防御、倒地、被投）
- `characters/shared/` 共用招式表（帧数据）
- `tools/` 精灵生成器、截图工具、输入脚本
- `tests/` 无头测试
