# Troubleshooter MOD — 先制反击 + 单天赋解锁附加天赋效果

《TROUBLESHOOTER: Abandoned Children》离线 MOD。核心玩法围绕「预热」BUFF 展开：为我方全员与友方单位提供一套天赋增益，绑定「先制反击」——敌人接近或施法时自动发动多段反击；同时放宽附加天赋（天赋套装）的解锁/生效/界面显示门槛，只装备少量子天赋即可获得套装完整效果。

MOD 成品为 `Mods/*.zip`，通过 TroubleTool 安装；源码修改位于 `Data/script`、`Data/xml`，由 `MODWORK/` 下的打包脚本生成各版本 zip。

---

## 一、我方全员与友方单位的天赋增益

### 触发方式
任意角色装备公司天赋「个人主义 (Individualism)」后：

- **战斗开始 (MissionBegin)**：给全部受益单位上/刷新「预热 (WarmUp)」BUFF，并补齐未拥有的附带天赋；
- **每位受益角色回合开始 (UnitTurnStart)**：再次刷新「预热」与附带天赋，保证整场战斗覆盖。

### 受益范围
仅 **同队 (Team，蓝方)** 与 **友善 (Ally，绿方)** 单位受益，包括开场中立、稍后加入我方的角色（在加入我方后以 Team/Ally 判定通过才发放）。**中立与敌方单位不享受**任何该 MOD 的增益。

### 附带天赋清单（装备「个人主义」后自动授予）
- **公司天赋**：Scavenger、CustomerSatisfaction、SenseOfBelonging、Pride、Individualism、Expertise（熟练）、HardFight（苦战）、SafetyFirst（安全第一）、FastWork（速战速决）
- **便利/收益类**：Learning、Understanding、Insight、TreasureHunter、AliBaba、Frankness、Yearning、PangOfConscience、Supporter、Immersion、PositiveMind、TreasureIsland、TreasureOfKing、Informant、MaterialCollector、GoldenCity、LegendaryServant、Expert、LargeTopPocket、LargeBottomPocket、GreatSupporter、Sortilege

> 已装备过的天赋不会重复授予；类名不存在的天赋自动跳过。

---

## 二、「预热 (WarmUp)」BUFF 的额外效果

持有预热 BUFF 的角色获得：

| 效果 | 来源 |
| --- | --- |
| 免疫敌人造成的回合等待延迟效果 | 原版 |
| **免疫敌人造成的技能禁用与技能冷却增加效果**（把冷却调大 / CD+N 的负面效果全部无效） | 本 MOD |
| **免疫精神异常** | 本 MOD |
| 免疫物理/精神减益、免疫敌人造成的延迟 | 原版 |
| 施法延迟时间减少 50% | 原版 |
| 速度 +20、命中 +10、闪避 +10、格挡 +10 | 原版 |
| **先制反击（见下节）** | 本 MOD |

BUFF 持续 3 回合，我方角色回合开始自动刷新，可全程覆盖。

---

## 三、先制反击 (Xzfj Forestallment) 的具体效果

### 触发条件（满足任一即可）
1. 敌人 **移动到自身半径 13 格内**（每次移动动作只触发一次，不会每走一格触发一次）；
2. 半径 13 格内的敌人 **使用技能时**。

> **稳定性说明（v1.1.0）**：移动触发在敌人移动的**过程中**（`UnitMovedSingleStep`）判定，而非整个移动结束后判定。这是引擎对「移动中反应攻击」的标准处理时机——当反击把正在移动的敌人击倒时，引擎会正常中断其移动命令，不会残留悬挂的等待命令。配合 `MoveIdentifier` 去重标记，保证敌人**一次移动动作只被反击一次**。此前的版本在敌人移动结束后才触发，若反击恰好击杀正在移动的敌人，会导致其 AI 的「等待到达目标格」命令永久挂起、回合卡死（已修复）。

### 反击特性
- **任意攻击技能**：远程 / 近身 / 范围 / 对地区 / SP / 道具类攻击技能均可使用；
- **技能轮换**：每次反击从可用攻击技能列表中轮换选取，不会一直用同一个技能；
- **命中率正常计算**：不设必中，正常享受命中增减益；
- **无视必然闪避**：反击不标记为反应攻击（ReactionAbility），因此**不会触发敌人「电光石火」「阴影猎人」的必然闪避反应攻击效果**，也不会触发针对反应攻击的联动/反制机制；
- **射程无视视野**：按技能射程直接判定，视野外的敌人只要距离在射程内同样会被反击；
- **触发无限制**：次数、回合、状态（移动中/施法中/被控制）均不限制，满足条件就触发；
- **允许互反**：可与敌人的反击互相交锋（敌方反击天赋自带的回合/次数保护会自然限制交锋轮数）；
- **反击不产生击退**：避免把执行中动作的敌人推走导致引擎卡死与连锁反击。

### 资源消耗与气魄
- 反击是**正常消耗资源的技能施放**（不使用免费标签）：正常消耗行动力 / SP / 弹药并进入冷却；
- 因此「消耗资源时获得 SP」类机制在反击中**同样生效**，连续反击可以积攒 SP/气魄，与主动技能施放完全对等。

### 反击后的增益
- **全技能 CD-1**：每次反击成功后，角色所有技能（含本次使用的技能）冷却 -1，鼓励多段反击连续施放；
- 多单位**并行齐射**：多个角色对同一敌人同时反击时几乎同时开火（nonsequential 并行调度），不再每人等待约 3 秒的演出停顿，快速过回合。

### 反应攻击天赋联动（先制反击享受全部加成）
| 天赋 | 对先制反击的加成 |
| --- | --- |
| 肉斩骨断 (Bonecrusher) | 必定命中 + 必定暴击 |
| 先见之明 (AcuityForestallment) | 必定命中 + 必定暴击 |
| 我在看着 (ImWatching) | 目标处于暴露状态时必定命中 + 必定暴击 |
| 我准备好了 (ImPreparedToDie) | 必定命中 |
| 报复 (Revenge) | 反击增伤（被命中档 100%） |
| 复仇连击 (RevengeStrikes) | 反击增伤 |
| 迎击 (CounterBlow) | 反击增伤 |
| 灰狙击手 (GreySniper) | 反击增伤 |
| 借力 (BorrowingEnergy) | 按「敌人对我方的理论最大伤害」（假设被命中且暴击、取各攻击技能伤害最大值）的 30% 计算反击增伤 |

---

## 四、单天赋解锁附加天赋效果（天赋套装阈值）

### 原版机制
天赋套装（Set Mastery，如 Argonaut、GoddessOfFortune、Ironman 等）需要**集齐套装全部子天赋**（通常 4 个），才会解锁图鉴信息、在战斗内生效、并在界面显示附加效果。

### 本 MOD 机制
装备的子天赋达到 **阈值 `XZJF_SetMasteryMinCount`** 个即视为套装成立，获得该套装**完整效果**，三个环节统一使用同一阈值：

1. **解锁**：图鉴/套装信息解锁（Lobby 的 `LobbyAction_AddMastery` 与 `CheckMasterySetIndex`）；
2. **实际生效**：战斗内 `GetSetMastery` 判定套装组成并注入套装 dummy，附加效果天赋完整生效；
3. **界面显示**：附加天赋效果栏（`GetMasterySetLackList`）展示该套装。

### 阵营界限
- **我方 (Team) 与友军 (Ally)**：享受放宽后的阈值判定；
- **中立 (None) 与敌方 (Enemy)**：保持原版判定（需集齐全部子天赋），避免敌我失衡。开场中立、稍后加入我方的角色仅在加入我方后才以 Team/Ally 判定通过。

### DATA 成品
`Data` 目录内阈值固定为 **1**（单天赋即解锁），多版本 zip 由打包脚本替换此值。

---

## 五、版本说明

### 本地 MOD 目录

| 目录 | 内容 |
| --- | --- |
| `Mods/` | 本地激活区：只放置**当前正在使用的 K1**（`XZJF_Mod_K1.zip`） |
| `Modsbackup/` | 本地备份区：K1 / K2 / K3 / K4 全部四个版本 |

| 文件 | 说明 |
| --- | --- |
| `XZJF_Mod_K1.zip` | 先制反击 + **单天赋**解锁/生效/显示（阈值 1） |
| `XZJF_Mod_K2.zip` | 先制反击 + **双天赋**解锁/生效/显示（阈值 2） |
| `XZJF_Mod_K3.zip` | 先制反击 + **三天赋**解锁/生效/显示（阈值 3） |
| `XZJF_Mod_K4.zip` | 先制反击 + **四天赋**解锁/生效/显示（阈值 4，相当于原版全收集） |

> 阈值 = 需装备几个子天赋即视为套装成立并获得完整附加效果。K1 最强势（单天赋成套装），K4 最接近原版（需集齐 4 个）。**每次只安装一个版本。**

### 版本历史

| 版本 | 说明 |
| --- | --- |
| v1.0.0 | 完整功能首发（K1-K4 四版本，TroubleTool + 中文文档）。 |
| v1.1.0 | **修复敌人移动中被先制反击击杀导致 AI 卡死**：移动触发改为在敌人移动过程中判定（`UnitMovedSingleStep`），用 `MoveIdentifier` 去重保证一次移动只反击一次；同时避免对不可达目标创建无效的等待订阅。 |

## 安装方式
1. 将选定的 `Mods/*.zip` 通过 TroubleTool 安装（需为 ASCII 文件名，引擎窄字符文件 API 无法识别中文名 zip）；
2. 游戏中为任意角色装备公司天赋「个人主义 (Individualism)」即可启动预热 + 先制反击 + 附带天赋的整套机制。

## 各文件来源
- `Data/script/server/buff.lua` — 先制反击核心逻辑（`XzfjForestall_*`），绑定预热 BUFF 事件；
- `Data/script/server/mastery.lua` — 个人主义关联、预热与附带天赋的分发；
- `Data/script/server/lobby.lua`、`lobby_enter.lua` — 套装解锁（Lobby）；
- `Data/script/shared/shared_mastery.lua` — 套装生效/界面显示统一阈值与阵营判定；
- `Data/script/server/battle.lua` — 预热免疫技能 CD 增加/禁用效果；
- `Data/xml/Buff.xml` — 预热 BUFF 定义与中文说明；
- `Data/xml/Mastery.xml`、`Data/xml/AbilityDirectingEvent.xml` — 天赋/事件定义；
- `MODWORK/make_ascii_mods.py` — 各版本 zip 打包脚本。
