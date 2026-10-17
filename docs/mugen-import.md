# 导入 MUGEN 人物（月姬格斗素材）

本工程可以读取 MUGEN 人物（`.def` + `.sff` + `.air`），把精灵和逐帧判定盒（Clsn1 攻击 / Clsn2 受击）转换成游戏使用的格式。
**招式、帧数据、规则仍然是本工程的 SF6 式设计**；MUGEN 人物只提供画面和判定盒的形状。

> ⚠️ 这些人物绝大多数是从商业游戏（TYPE-MOON / 渡边制作所《MELTY BLOOD》）提取的素材，版权不属于你我。
> 只能放在本机的 `local_assets/`（已在 `.gitignore` 中）自己使用，**不要提交到公开仓库，也不要再分发**。
> 下载站点都是第三方网盘，下载后请先杀毒再解压。

## 角色对应

| 本工程定位 | 月姬格斗角色 | 映射文件 | 招式表 |
|---|---|---|---|
| 速攻（短刀） | 远野志贵 Shiki Tohno | `tools/mugen/maps/shiki.json` | Kagura |
| 投技（重量级） | 轧间翽马 Kouma Kishima | `tools/mugen/maps/kouma.json` | Volk |
| 远程 | 希尔 Ciel | `tools/mugen/maps/ciel.json` | Mio |

## 去哪里找（按 日语 → 英语 → 中文 → 俄语 的顺序查过）

- **日语**：ニコニコMUGENwiki 的角色页列出各作者版本和配布页链接，例如
  [遠野志貴](https://w.atwiki.jp/niconicomugen/pages/77.html)、
  [七夜志貴](https://w.atwiki.jp/niconicomugen/pages/94.html)。
- **英语**：Mugen Free For All 的 [Melty Blood Collection](https://mugenfreeforall.com/topic/50645-melty-blood-collection/)
  与 [Melty Blood: Type Lumina](https://mugenfreeforall.com/topic/48399-melty-blood-type-lumina/) 合集帖（按作者列出、标明是否失效）；
  AK1 MUGEN Community 的 Melty Blood 分类，例如
  [Shiki Tohno](https://www.andersonkenya1.net/files/file/21732-shiki-tohno/)、
  [Shiki Tohno (Type Lumina)](https://www.andersonkenya1.net/files/file/20117-shiki-tohno-type-lumina/)。
  原作精灵图拆包在 [The Spriters Resource](https://www.spriters-resource.com/playstation_2/mbaa/)（只有图，没有判定盒）。
- **中文**：[qxmugen 远野志贵](https://qxmugen.com/character/16063) 等人物页（标注作者、强度）。
- **俄语**：没有找到俄语社区的独立发布，搜索结果都指回上面的英文站点。

挑选建议：优先选 **MUGEN 1.0/1.1 版、按 MBAACC 原作数据移植** 的版本（判定盒更接近原作）；
同一个角色有多个作者版本时，`.def` 里的 `author` 可以区分。

## 步骤

1. 把下载的人物解压到 `local_assets/mugen_src/<名字>/`（目录里要有 `.def`、`.sff`、`.air`）。
2. 看这个人物有哪些动作、哪些带攻击判定：
   ```bash
   python3 tools/mugen/import_char.py list local_assets/mugen_src/<名字>
   ```
   输出每个动作号的帧数、总时长、攻击帧范围，标准动作（0 站立、20/21 走、40-47 跳、150/152 防御、5000 系受击……）会标注名字。
3. 打开对应的映射文件（如 `tools/mugen/maps/shiki.json`），按 `list` 的结果修改：
   - 普攻：月姬格斗是 A/B/C 三键，模板按常见编号 200/210/220（站）、400/410/420（蹲）、600/610/620（空中）填写，
     踢腿暂时借用同强度的拳；**以 `list` 的实际编号为准**。
   - 必杀技：`_todo_specials` 里列出了本工程的必杀动画名，把对应的动作号填进 `anims`。
   - 值的写法：`0`（一个动作）、`[10, 11]`（多个动作首尾相接）、`{"frames": [[41, 0], [41, -1]]}`（手动挑帧，-1 为最后一帧）。
4. 导入（可以把映射文件复制到 `local_assets/` 再改，避免改动仓库里的模板）：
   ```bash
   python3 tools/mugen/import_char.py import local_assets/mugen_src/<名字> tools/mugen/maps/shiki.json
   ```
   输出到 `local_assets/mugen/shiki/`：`sprites/`（PNG + anims.json）和 `fighter.tres`。
5. 用 Godot 打开工程（会自动导入新 PNG），训练场景里按 F8 / F9 切换到导入的角色。按 F1 看判定框是否贴合。

## 转换规则

- 带 Clsn1 的动作会压成五帧攻击动画（蓄力 / 出手 / 持续 / 收势 / 复原）：持续帧的攻击盒取所有攻击帧 Clsn1 的并集，
  每帧受击盒取该帧的 Clsn2。出招时机仍由本工程招式表的发生 / 持续 / 收招帧数决定，按阶段选帧。
- 其他动作保留原来每帧的时长。
- 所有帧拼到同一张画布上（脚底锚点对齐），显示缩放 = `target_height` ÷ 站立图高度。
- 调色板：SFF v2 用 (1,1) 作为 1P 色、(1,2) 作为同角色镜像时的 2P 色；SFF v1 用 `.def` 里的 pal1 / pal2（.act）。
- 推挤盒、投判定仍用本工程的规则数据（SF6 式），不读 MUGEN 的设定。

## 已知限制

- SFF v2 的 RLE5 / LZ5（只用于 32 色精灵）按公开引擎实现编写，**没有拿真实文件验证过**；
  如果某些精灵解出来是乱的，用 Fighter Factory 把它们重新存成 RLE8 或 PNG 再导入。
- `.act` 调色板按 MUGEN 惯例倒序读取；如果颜色整体错乱，在 `sff.load_act` 里去掉 `reverse()`。
- 没有映射的动画会用站立图代替，判定回退到招式表里手写的盒子。
- 飞行道具的特效图暂不从 MUGEN 人物里导入（显示为默认光球）。

## 自测

```bash
python3 -m unittest discover -s tools/mugen -p "test_*.py"
python3 tools/mugen/make_sample.py kagura   # 把程序化 Kagura 打包成 MUGEN 格式样例，再用上面的 import 导回来
```
