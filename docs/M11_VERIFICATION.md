# M11 元游戏系统 — 验证清单

> 最后更新：2026-06-10
> 修改文件：`CGFBoard.gd`（地图/商店/休息流程+遗物显示+金币奖励）、`CombatManager.gd`（遗物 hook）、`RewardScreen.gd`（金币激活）、`RunState.gd`（完全重写）
> 新建文件：`RelicDatabase.gd`（5 遗物）、`MapGenerator.gd`（15 层地图生成）、`MapScreen.gd`（地图 UI）、`ShopScreen.gd`（商店 UI）

---

## 阶段 0：RunState 数据模型

### 0.1 基础字段

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| gold 字段 | 初始 gold = 99 | MCP: run_state.gold=99 | [ ] |
| relics 字段 | 初始 relics = [] | MCP: run_state.relics = [] | [ ] |
| player_strength | 初始 player_strength = 0 | MCP: run_state.player_strength=0 | [ ] |
| player_hp | 初始 80/80 | MCP: player_hp=80 | [ ] |
| deck_card_names | 10 张初始牌 | MCP: size=10 | [ ] |
| map_data | 非空，含 floors | MCP: map_data 非空 | [ ] |
| current_floor | 初始 -1 | MCP: current_floor=-1 | [ ] |

### 0.2 地图数据

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 总层数 15 | floors.size() = 15 | MCP: floors.size()=15 | [ ] |
| 第 0 层全战斗 | floor 0 全是 combat | MCP: floor0 types 全 combat | [ ] |
| 第 14 层 Boss | floor 14 只有 boss | MCP: floor14 type=boss | [ ] |
| 每层 3-4 节点 | floors[i].size() ∈ [1,5] | MCP: 各层 size 确认 | [ ] |
| 节点有 x 坐标 | 每个 node 有 x 字段 | MCP: node["x"] 存在 | [ ] |
| 节点有连接 | 非最后一层节点有 connections | MCP: connections 非空 | [ ] |
| 有效路径 | 从 floor 0 可到达 floor 14 | MCP: get_reachable_nodes 非空 | [ ] |

### 0.3 地图导航

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| get_starting_nodes | 返回 floor 0 所有节点 | MCP: size >= 3 | [ ] |
| get_reachable_nodes (初始) | 返回 floor 0 节点 | MCP: floor_index=0 | [ ] |
| move_to_node | 更新 current_floor 和 current_node_index | MCP: move→floor=0, node=1 | [ ] |
| get_reachable_nodes (移动后) | 返回下一层可达节点 | MCP: 来自 connections | [ ] |
| is_current_node_final | Boss 层返回 true | MCP: floor=14 → true | [ ] |
| get_floor_number | 1-based 楼层号 | MCP: floor=0 → 1 | [ ] |
| get_total_floors | 返回 15 | MCP: =15 | [ ] |

### 0.4 Encounter 生成

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| combat 节点 | 返回普通敌人配置 | MCP: type=combat → 正常敌人 | [ ] |
| elite 节点 | 返回精英敌人配置 | MCP: type=elite → elite 敌人 | [ ] |
| boss 节点 | 返回 Boss 配置 | MCP: type=boss → heart_mimic | [ ] |
| 楼层缩放 HP | 高楼层 HP 更高 | MCP: floor0 vs floor10 HP 差异 | [ ] |
| 楼层缩放 damage | 高楼层伤害更高 | MCP: moves damage 差异 | [ ] |

### 0.5 Gold 系统

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| add_gold | gold += amount | MCP: add_gold(50) → gold=149 | [ ] |
| spend_gold (够) | gold -= amount, return true | MCP: spend_gold(30) → true, gold=119 | [ ] |
| spend_gold (不够) | gold 不变, return false | MCP: spend_gold(999) → false | [ ] |
| get_gold_reward (combat) | 20 + floor * 3 | MCP: floor=5 → 35 | [ ] |
| get_gold_reward (elite) | 40 + floor * 5 | MCP: type=elite → 更高 | [ ] |
| get_gold_reward (boss) | 100 | MCP: type=boss → 100 | [ ] |
| lucky_cat 加成 | +15 金币 | MCP: 有 lucky_cat → +15 | [ ] |

### 0.6 Relic 系统

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| add_relic | 添加到 relics 数组 | MCP: add_relic("x") → has=true | [ ] |
| add_relic 不重复 | 同一遗物不重复添加 | MCP: add 两次 → size=1 | [ ] |
| has_relic | 检查遗物是否拥有 | MCP: has=false → add → has=true | [ ] |
| is_elite_or_boss (combat) | false | MCP: type=combat → false | [ ] |
| is_elite_or_boss (elite) | true | MCP: type=elite → true | [ ] |
| is_elite_or_boss (boss) | true | MCP: type=boss → true | [ ] |

### 0.7 Deck 操作

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| remove_card_from_deck | 移除指定卡牌 | MCP: remove "Bash" → 无 Bash | [ ] |
| remove 不存在的卡 | return false | MCP: remove "XXX" → false | [ ] |

---

## 阶段 1：RelicDatabase

### 1.1 遗物定义

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 5 个遗物 | RELICS.size() = 5 | MCP: size=5 | [ ] |
| orichalcum | 橄榄石, common, price=100 | MCP: get_relic 确认 | [ ] |
| burning_blade | 燃烧之刃, uncommon, price=150 | MCP: get_relic 确认 | [ ] |
| red_skull | 赤红之颅, uncommon, price=150 | MCP: get_relic 确认 | [ ] |
| vampire_eye | 吸血之眼, rare, price=200 | MCP: get_relic 确认 | [ ] |
| lucky_cat | 招财猫, common, price=100 | MCP: get_relic 确认 | [ ] |

### 1.2 查询接口

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| get_relic (存在) | 返回字典含 name/icon/description | MCP: 非空确认 | [ ] |
| get_relic (不存在) | 返回 {} 并 push_error | MCP: 返回空字典 | [ ] |
| get_all_ids | 返回 5 个 id | MCP: size=5 | [ ] |
| get_random_relic | 返回随机遗物 id | MCP: 非 empty | [ ] |
| get_random_relic (exclude) | 排除已有遗物 | MCP: exclude 全部 → "" | [ ] |

---

## 阶段 2：MapGenerator

### 2.1 地图生成

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| generate 返回有效数据 | 含 floors, start_floor | MCP: 非空确认 | [ ] |
| 节点类型合法 | type ∈ {combat, elite, shop, rest, boss} | MCP: 所有 type 合法 | [ ] |
| 连接有效 | connections 索引在下一层范围内 | MCP: 无越界 | [ ] |
| 每层至少 1 节点 | floors[i].size() >= 1 | MCP: 确认 | [ ] |
| NODE_CONFIG | 5 种节点类型都有 icon 和 color | MCP: 全部存在 | [ ] |

---

## 阶段 3：CombatManager 遗物 Hook

### 3.1 Hook 基础设施

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| _first_attack_this_turn | 变量存在，初始 true | MCP: 变量确认 | [ ] |
| start_turn 重置 flag | _first_attack_this_turn = true | MCP: 每回合重置 | [ ] |
| _apply_relic_effect | 方法存在 | MCP: 方法存在确认 | [ ] |

### 3.2 Orichalcum（橄榄石）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 回合开始 +4 block | 有遗物时 gain_block(4) | MCP: 遗物+start_turn→block=4 | [ ] |
| 无遗物时不触发 | block 不变 | MCP: 无遗物→block=0 | [ ] |

### 3.3 Burning Blade（燃烧之刃）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 首攻 +3 伤害 | 第一次攻击伤害 +3 | MCP: 有遗物→damage+3 | [ ] |
| 后续攻击无加成 | _first_attack = false 后不再加 | MCP: 第二次攻击无加成 | [ ] |
| 无遗物正常 | 伤害不受影响 | MCP: 无遗物→damage 正常 | [ ] |

### 3.4 Vampire Eye（吸血之眼）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 攻击回血 2 HP | 造成伤害后 heal(2) | MCP: 有遗物→hp+2 | [ ] |
| 0 伤害不触发 | damage=0 时不 heal | MCP: 0伤害→hp 不变 | [ ] |

### 3.5 Red Skull（赤红之颅）— CGFBoard 处理

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 精英/Boss 击杀 +2 力量 | combat_ended → player_strength += 2 | MCP: 精英击杀后 strength | [ ] |
| 普通怪不触发 | player_strength 不变 | MCP: 普通怪→不变 | [ ] |

### 3.6 Lucky Cat（招财猫）— RunState 处理

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 战斗金币 +15 | get_gold_reward 额外 +15 | MCP: 已在 0.5 测试 | [ ] |

---

## 阶段 4：地图 UI

### 4.1 MapScreen 基础

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| setup 接受参数 | viewport_size, run_state | MCP: 脚本加载无错 | [ ] |
| show_map 显示 | visible = true | 手动 | [ ] |
| node_selected 信号 | 点击节点触发 | 手动 | [ ] |
| 节点按类型着色 | combat 绿/elite 橙/shop 金/rest 红/boss 深红 | 手动 | [ ] |
| 连线可见 | 节点间有连线 | 手动 | [ ] |
| 可达节点高亮 | 连接的节点有金色边框 | 手动 | [ ] |
| 滚动 | 15 层可垂直滚动 | 手动 | [ ] |
| 信息栏显示 | HP/金币/遗物/楼层 | 手动 | [ ] |

---

## 阶段 5：商店系统

### 5.1 ShopScreen 基础

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| setup 接受参数 | viewport_size, run_state, board | MCP: 脚本加载无错 | [ ] |
| shop_closed 信号 | 离开商店触发 | 手动 | [ ] |
| 卡牌定价 | Common=50/Uncommon=75/Rare=100 | 源码确认 | [ ] |
| 删除卡牌定价 | 75 金 | 源码确认 | [ ] |
| 回血定价 | 50 金，回复 30% HP | 源码确认 | [ ] |
| 遗物定价 | 使用 RelicDatabase 的 price | 源码确认 | [ ] |

### 5.2 购买逻辑

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 买牌 (够钱) | gold 减少，卡牌加入 deck | 手动 | [ ] |
| 买牌 (不够钱) | 显示金币不足 | 手动 | [ ] |
| 回血 (够钱) | gold 减少，HP 增加 | 手动 | [ ] |
| 删除卡牌 | gold 减少，卡牌从 deck 移除 | 手动 | [ ] |
| 买遗物 (够钱) | gold 减少，遗物添加 | 手动 | [ ] |
| 金币实时更新 | 购买后金币显示更新 | 手动 | [ ] |

---

## 阶段 6：CGFBoard 流程整合

### 6.1 地图驱动流程

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 启动显示地图 | _start_run → _show_map_screen | 手动 | [ ] |
| 选战斗节点 → 战斗 | 点击战斗节点进入 combat | 手动 | [ ] |
| 选商店节点 → 商店 | 点击商店节点进入 shop | 手动 | [ ] |
| 选休息节点 → 回血 | 点击休息节点回复 HP | 手动 | [ ] |
| 战斗胜利 → 奖励 → 地图 | 战斗结束→奖励→回到地图 | 手动 | [ ] |
| 商店关闭 → 地图 | 离开商店回到地图 | 手动 | [ ] |
| Boss 击杀 → Run Complete | 最终层 Boss 胜利→完成 | 手动 | [ ] |
| 死亡 → Game Over | 战斗失败→Game Over | 手动 | [ ] |

### 6.2 持久状态

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP 跨战斗保持 | 上一场剩余 HP = 下一场初始 HP | 手动 | [ ] |
| 金币跨战斗累积 | 战斗奖励金币累积 | 手动 | [ ] |
| 遗物跨战斗生效 | 获得的遗物在后续战斗中生效 | 手动 | [ ] |
| player_strength 持久 | Red Skull 加的力量保留 | 手动 | [ ] |
| 奖励卡牌加入牌组 | 选择的奖励卡出现在后续战斗 | 手动 | [ ] |
| 删除卡牌生效 | 商店删除的卡不出现在后续战斗 | 手动 | [ ] |

### 6.3 遗物 UI

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 战斗界面遗物图标 | 遗物 emoji 显示在 encounter label 旁 | 手动 | [ ] |
| 地图界面遗物图标 | 信息栏显示遗物 | 手动 | [ ] |
| 遗物获得提示 | elite/boss 掉落遗物时显示 toast | 手动 | [ ] |

---

## 运行时错误检查

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| SCRIPT ERROR | 0 个 | MCP | [ ] |
| Parser Error | 0 个 | MCP | [ ] |
| 信号连接完整 | healed/thorns_triggered/poison_damaged 全连接 | MCP | [ ] |

---

## 测试结果汇总

| # | 测试项 | 验证 | 备注 |
|---|--------|------|------|
| 0.1 | RunState 基础字段 | MCP | gold/relics/strength/hp/map |
| 0.2 | 地图数据 | MCP | 15 层/节点/连接 |
| 0.3 | 地图导航 | MCP | reachable/move/final |
| 0.4 | Encounter 生成 | MCP | combat/elite/boss/缩放 |
| 0.5 | Gold 系统 | MCP | add/spend/reward/lucky_cat |
| 0.6 | Relic 系统 | MCP | add/has/is_elite |
| 0.7 | Deck 操作 | MCP | remove |
| 1.1 | RelicDatabase 定义 | MCP | 5 遗物/字段完整 |
| 1.2 | RelicDatabase 查询 | MCP | get/random/exclude |
| 2.1 | MapGenerator | MCP | 生成/类型/连接 |
| 3.1 | Hook 基础设施 | MCP | flag/method |
| 3.2 | Orichalcum | MCP | +4 block |
| 3.3 | Burning Blade | MCP | 首攻+3 |
| 3.4 | Vampire Eye | MCP | 攻击回血 |
| 3.5 | Red Skull | MCP | 精英+2str |
| 3.6 | Lucky Cat | MCP | +15gold |
| 4.1 | 地图 UI | 手动 | 显示/交互/信息 |
| 5.1 | 商店基础 | MCP+手动 | 定价/信号 |
| 5.2 | 购买逻辑 | 手动 | 买牌/回血/删牌/买遗物 |
| 6.1 | 流程整合 | 手动 | 地图→战斗/商店/休息→循环 |
| 6.2 | 持久状态 | 手动 | HP/金币/遗物/力量跨战斗 |
| 6.3 | 遗物 UI | 手动 | 图标/toast |
| — | 运行时错误 | MCP | 0 SCRIPT ERROR |

---

## 待手动验证项

以下需要人眼确认，无法通过 MCP 自动验证：

- [ ] 地图节点按类型正确着色（⚔️绿/💀橙/💰金/❤️红/👑深红）
- [ ] 节点间连线清晰可见，不遮挡节点
- [ ] 可达节点有脉冲高亮动画
- [ ] 地图可以垂直滚动查看全部 15 层
- [ ] 商店界面显示 5 张待售卡牌 + 回血 + 删牌 + 遗物
- [ ] 休息节点回复后显示 toast 通知
- [ ] 战斗界面遗物 emoji 图标可见
- [ ] 遗物获得 toast 通知可见（elite/boss 掉落）
- [ ] 金币奖励在奖励界面正确显示
- [ ] 完整 15 层地图流程可正常完成（开始→地图→战斗→奖励→地图→…→Boss→Run Complete）
- [ ] Game Over 后可返回主菜单
- [ ] 新 Run 重置所有状态（HP/金币/遗物/牌组/地图）
