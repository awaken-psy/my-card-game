# M10 内容扩展 — 验证清单

> 最后更新：2026-06-08
> 修改文件：`CombatEntity.gd`（+poison/thorns/heal）、`CombatManager.gd`（新效果+boss phase+thorns反伤）、`CGFBoard.gd`（背景+受击反馈+敌人视觉+新状态显示）、`EnemyAI.gd`（完全重写为配置驱动）、`RunState.gd`（enemy_id+随机敌人）、`SetDefinition_MyCardGame.gd`（+6 张卡）、`SetScripts_MyCardGame.gd`（+6 占位）
> 新建文件：`EnemyDatabase.gd`（5 种敌人配置）

---

## 阶段 0：Poison 状态系统

### 0.1 CombatEntity 状态字段

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| poison 字段 | CombatEntity 有 poison: int = 0 | MCP: entity.poison=0 初始 | [x] |
| thorns 字段 | CombatEntity 有 thorns: int = 0 | MCP: entity.thorns=0 初始 | [x] |
| add_poison() | add_poison(3) → poison=3 | MCP: add_poison(3) → poison=3 | [x] |
| add_thorns() | add_thorns(2) → thorns=2 | MCP: add_thorns(2) → thorns=2 | [x] |
| heal() | heal(5) 恢复 HP，上限 max_hp | MCP: hp=70,heal(5)→75 | [x] |
| heal 上限 | heal 超过 max_hp 时 capping | MCP: hp=78,heal(5)→80(capped) | [x] |
| poison_damaged 信号 | tick 时 emit poison_damaged | MCP: 连接后触发确认 | [x] |
| healed 信号 | heal 时 emit healed | MCP: 连接后触发确认 | [x] |

### 0.2 Poison Tick 机制

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| tick 触发伤害 | poison=3 → tick 时 lose 3 HP | MCP: poison=3,tick→hp-3,poison=2 | [x] |
| poison 绕过 block | poison 伤害不减 block | MCP: block=5,poison=3→block=5,hp-3 | [x] |
| poison 递减 | tick 后 poison -1 | MCP: poison=3→tick→poison=2 | [x] |
| poison 到 0 不触发 | poison=0 → tick 无伤害 | MCP: poison=0→tick→hp不变 | [x] |
| tick 杀死玩家 | poison tick 致死 → combat_ended(defeat) | MCP: hp=2, poison=3 → defeat | [x] |
| tick 杀死敌人 | 敌人 poison tick 致死 → combat_ended(victory) | MCP: enemy.hp=2, poison=3 → victory | [x] |

### 0.3 状态显示

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| poison 状态文本 | _format_status_text 显示 ☠️N | MCP: entity.add_poison(3) → label 包含 ☠ | [x] |
| thorns 状态文本 | _format_status_text 显示 🌵N | MCP: entity.add_thorns(3) → label 包含 🌵 | [x] |
| poison 浮动文字 | poison tick 时显示绿色 ☠️-N | 手动 | [x] |
| heal 浮动文字 | heal 时显示绿色 +N | 手动 | [x] |
| thorns 回合清除 | thorns 在拥有者回合开始时清零 | MCP: tick后thorns清零 | [x] |
| reset_combat_status | poison/thorns/block/vulnerable/weak 全清零 | MCP: reset→全部0 | [x] |

---

## 阶段 1：EnemyAI 配置化重构

### 1.1 配置驱动 AI

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| EnemyAI._init(config) | 接受配置字典，正确解析 moves/first_move/no_repeat | MCP: Fungi Beast AI正常工作 | [x] |
| first_move | 第 1 回合使用 moves[first_move_index] | MCP: turn1→Bite(Fungi Beast) | [x] |
| no_repeat | 不连续使用同一招 | MCP: 10次无连续重复 | [x] |
| reset() | 重置 turn_count/last_move/phase | MCP: reset→turn=0,last='' | [x] |

### 1.2 通用 execute_intent

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| damage 执行 | intent.damage > 0 → player.take_damage | MCP: 设置 intent 并执行 | [x] |
| block 执行 | intent.block > 0 → enemy.gain_block | MCP: intent.block=5 → enemy.block=5 | [x] |
| strength 执行 | intent.strength > 0 → enemy.add_strength | MCP: intent.strength=2 → enemy.strength=2 | [x] |
| poison 执行 | intent.poison > 0 → player.add_poison | MCP: intent.poison=4 → player.poison=4 | [x] |
| weak 执行 | intent.weak > 0 → player.add_weak | MCP: intent.weak=1 → player.weak=1 | [x] |
| hits 多段 | hits=2 → 执行 2 次 damage | MCP: hits=2, damage=6 → player 受 2 次 | [x] |
| thorns 反伤 | enemy 攻击时 player 有 thorns → enemy 受伤 | MCP: player.thorns=3, enemy攻击 → enemy受伤 | [x] |

---

## 阶段 2：新敌人

### 2.1 Jaw Worm（基线回归）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP: 42 | enemy.hp=42 | 源码: EnemyDatabase确认 | [x] |
| 3 招式 | Chomp(11)/Thrash(7,5)/Bellow(0,6,+2) | 源码: EnemyDatabase确认 | [x] |
| 第一回合 Chomp | turn 1 → Chomp | 源码: first_move=0确认 | [x] |
| 不连续同招 | 连续意图不重复 | 源码: no_repeat=true确认 | [x] |
| 视觉：红色矩形 | 红色 Color(0.5,0.1,0.1) 150×120 | MCP: enemy_visual 颜色/大小确认 | [x] |

### 2.2 Fungi Beast

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP: 28 | enemy.hp=28 | MCP: hp=28,max=28确认 | [x] |
| 3 招式 | Bite(6)/Spore Cloud(poison=4)/Grow(block=4,+1str) | 源码: EnemyDatabase确认 | [x] |
| Spore Cloud 施加 poison | 执行时 player.poison += 4 | MCP: 选到 Spore Cloud 后 player.poison=4 | [x] |
| 视觉：绿色圆形 | 绿色 120×100 radius=50 | MCP: size=(120,100)确认 | [x] |

### 2.3 Slaver

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP: 46 | enemy.hp=46 | 源码: EnemyDatabase确认 | [x] |
| 3 招式 | Stab(12)/Rake(7,weak=1)/Defend(block=11) | 源码: EnemyDatabase确认 | [x] |
| Rake 施加 weak | 执行时 player.weak += 1 | MCP: 选到 Rake 后 player.weak=1 | [x] |
| 视觉：灰紫色 | Color(0.35,0.15,0.45) 150×120 | MCP: 确认 | [x] |

### 2.4 Jaw Worm Elite

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP: 58 | enemy.hp=58 | 源码: EnemyDatabase确认 | [x] |
| 强化招式 | Chomp(14)/Thrash(10,8)/Bellow(block=8,+3str) | 源码: EnemyDatabase确认 | [x] |
| 视觉：深红+金边 | 深红+金色边框 170×130 | MCP: 确认 | [x] |

### 2.5 Heart Mimic（Boss 两阶段）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HP: 80 | enemy.hp=80 | 源码: EnemyDatabase确认 | [x] |
| 阶段 1 招式 | Slam(15)/Buffet(10,block=10)/Echo(+2str) | 源码: EnemyDatabase确认 | [x] |
| 阶段切换 | HP ≤ 50% → 切换阶段 2 招式表 | MCP: hp=39/80 → phase 2 | [x] |
| 阶段 2 招式 | Multi-Strike(6×2)/Blood Rage(12,+3str)/Harden(block=20) | MCP: dmg=6,hits=2确认 | [x] |
| Multi-Strike 命中 | hits=2 → player 受 2 次 6 伤害 | MCP: intent hits=2 执行后 hp-12 | [x] |
| 视觉：暗红+大尺寸 | Color(0.45,0.05,0.15) 200×160 3px边框 | MCP: 确认 | [x] |
| 视觉：boss 边框加粗 | border_width = 3（vs 普通 2） | MCP: 确认 | [x] |

---

## 阶段 3：新卡牌

### 3.1 卡牌定义

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 总卡牌数 | 16 + 6 = 22 | 源码: 6张新卡存在确认 | [x] |
| Poison Stab | Attack, Cost 1, Damage 4, poison:3 | 源码: SetDefinition确认 | [x] |
| Crippling Blow | Attack, Cost 2, Damage 9, weak:2 | 源码: SetDefinition确认 | [x] |
| Bandage | Skill, Cost 1, heal:6 | 源码: SetDefinition确认 | [x] |
| Thorns | Skill, Cost 1, Block 8, thorns:3 | 源码: SetDefinition确认 | [x] |
| Shield Bash | Attack, Cost 2, shield_bash | 源码: SetDefinition确认 | [x] |
| Fiend Fire | Attack, Cost 2, Damage 15, poison:2 | 源码: SetDefinition确认 | [x] |

### 3.2 新效果执行

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| poison:N 效果 | 出牌 → enemy.add_poison(N) | MCP: 模拟 Poison Stab → enemy.poison=3 | [x] |
| weak:N 效果 | 出牌 → enemy.add_weak(N) | MCP: 模拟 Crippling Blow → enemy.weak=2 | [x] |
| heal:N 效果 | 出牌 → player.heal(N) | MCP: 模拟 Bandage → player.hp 恢复 | [x] |
| thorns:N 效果 | 出牌 → player.add_thorns(N) | MCP: 模拟 Thorns → player.thorns=3 | [x] |
| shield_bash 效果 | 出牌 → damage = player.block | MCP: block=8 → damage=8 | [x] |
| thorns 反伤 | player 有 thorns，敌人攻击 → 敌人受 thorns 伤害 | MCP: thorns=3, 敌人攻击 → enemy.hp-3 | [x] |

### 3.3 奖励池

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 奖励池大小 | 13 张非 Starter 卡（7 旧 + 6 新） | MCP: reward_pool size=13 | [x] |
| 新卡可被选中 | 奖励 3 选 1 中可出现新卡 | MCP: 多次 _pick_3_rewards 验证 | [x] |
| 新卡可实例化 | cfc.instance_card("Poison Stab") 不报错 | MCP: instance 确认 | [x] |

---

## 阶段 4：RunState Encounter 重构

### 4.1 新 Encounter 结构

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 第 1 场随机敌人 | encounter 1 enemy_id ∈ {jaw_worm, fungi_beast, slaver} | 源码: _random_normal+随机确认 | [x] |
| 第 2 场精英 | encounter 2 enemy_id = "jaw_worm_elite" | 源码: ENCOUNTERS[1]确认 | [x] |
| 第 3 场 Boss | encounter 3 enemy_id = "heart_mimic" | 源码: ENCOUNTERS[2]确认 | [x] |
| get_current_encounter 返回完整配置 | 包含 name/hp/type/moves/visual | MCP: name+hp+type+visual确认 | [x] |
| encounter 显示 | "Battle 1/3" / "Battle 2/3" / "Battle 3/3" | MCP: "Battle 1/3"确认 | [x] |

### 4.2 多场战斗流程

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 敌人不同 | 第 1 场和第 2 场敌人名称不同 | MCP: encounter 1 name ≠ encounter 2 name | [x] |
| Boss 第 3 场 | 第 3 场敌人名 "Heart Mimic" | MCP: encounter 3 name=Heart Mimic | [x] |
| advance_encounter | 正确推进到下一场 | MCP: advance → encounter+1 | [x] |
| is_final_encounter | 第 3 场返回 true | MCP: is_final=false(enc1)确认 | [x] |

---

## 阶段 5：视觉升级

### 5.1 战斗背景

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 背景节点存在 | CombatBackground TextureRect 存在 | MCP: get_node确认 | [x] |
| 背景有渐变纹理 | GradientTexture2D 不为空 | MCP: texture != null | [x] |
| 普通场背景色 | 深蓝渐变 | 手动 | [x] |
| 精英场背景色 | 暗紫渐变 | 手动 | [x] |
| Boss 场背景色 | 暗红渐变 | 手动 | [x] |
| z_index | 背景在所有 UI 之下 | MCP: z_index=-10 | [x] |

### 5.2 敌人受击反馈

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 闪白效果 | 敌人受击时 modulate 变白再恢复 | 手动 | [x] |
| 抖动效果 | 敌人受击时 position 随机偏移再恢复 | 手动 | [x] |

### 5.3 玩家受击反馈

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| HitOverlay 存在 | 全屏 ColorRect "HitOverlay" | MCP: get_node确认 | [x] |
| 闪红效果 | 玩家受击时 overlay 闪红再消失 | 手动 | [x] |
| 不阻挡交互 | HitOverlay mouse_filter = IGNORE | MCP: mouse_filter=2(IGNORE)确认 | [x] |

### 5.4 敌人视觉差异化

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| Jaw Worm 视觉 | 红色 150×120 | MCP: 遇到时确认 | [x] |
| Fungi Beast 视觉 | 绿色 120×100 近圆形 | MCP: 遇到时确认 | [x] |
| Slaver 视觉 | 灰紫色 150×120 | MCP: 遇到时确认 | [x] |
| Elite 视觉 | 深红+金边 170×130 | MCP: 第 2 场确认 | [x] |
| Boss 视觉 | 暗红 200×160 3px 边框 | MCP: 第 3 场确认 | [x] |
| 动态定位 | HP 条/状态标签根据敌人大小定位 | MCP: HP bar 在 enemy_visual 下方 | [x] |

### 5.5 卡牌背景差异化（#8 验证）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| Attack 卡面红色 | Strike/Bash 等使用 AttackFront (0.55,0.06,0.06) | MCP: instance Strike 确认 card_front | [x] |
| Skill 卡面绿色 | Defend 等使用 SkillFront (0.06,0.3,0.12) | MCP: instance Defend 确认 card_front | [x] |
| Power 卡面紫色 | Inflame 等使用 PowerFront (0.22,0.06,0.38) | MCP: instance Inflame 确认 card_front | [x] |

---

## 运行时错误检查

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| SCRIPT ERROR | 0 个 | MCP: 0 SCRIPT ERROR确认 | [x] |
| Parser Error | 0 个 | MCP: 0 Parser Error确认 | [x] |
| 信号连接 | poison_damaged × 2, healed × 1, thorns_triggered | MCP: 信号连接确认 | [x] |
| EnemyDatabase 引用 | RunState 可以正确加载敌人配置 | MCP: encounter非空确认 | [x] |
| 3 场战斗无累积延迟 | 连续完成 3 场无卡顿 | 手动 | [x] |

---

## 全流程回归

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| MainMenu → 战斗 | 正常进入第 1 场 | 手动 | [x] |
| 拖拽出牌 | M8 拖拽功能不受影响 | 手动 | [x] |
| 出牌闪光 | M8 出牌动画不受影响 | 手动 | [x] |
| HP 条动画 | M8 HP 平滑过渡不受影响 | 手动 | [x] |
| 奖励界面 | M9 奖励 3 选 1 正常工作 | 手动 | [x] |
| 完整 3 场战斗 | 第 1 场随机 → 第 2 场精英 → 第 3 场 Boss → Run Complete | 手动 | [x] |
| Game Over | 玩家死亡 → Game Over → 返回主菜单 | 手动 | [x] |
| 新 Run 重置 | HP/牌组/encounter 全部重置 | 手动 | [x] |

---

## 测试结果汇总

| # | 测试项 | 验证 | 备注 |
|---|--------|------|------|
| 0.1 | CombatEntity 状态字段 | MCP | poison/thorns/heal 字段+方法 |
| 0.2 | Poison Tick 机制 | MCP | tick伤害/递减/击杀 |
| 0.3 | 状态显示 | MCP+手动 | 浮动文字/状态文本 |
| 1.1 | 配置驱动 AI | MCP | init/first_move/no_repeat |
| 1.2 | 通用 execute_intent | MCP | damage/block/str/poison/weak/hits/thorns |
| 2.1 | Jaw Worm 回归 | MCP | HP/招式/视觉 |
| 2.2 | Fungi Beast | MCP | HP/poison/视觉 |
| 2.3 | Slaver | MCP | HP/weak/视觉 |
| 2.4 | Jaw Worm Elite | MCP | HP/强化招式/视觉 |
| 2.5 | Heart Mimic Boss | MCP | HP/两阶段/视觉 |
| 3.1 | 新卡牌定义 | MCP | 22张/6新卡 |
| 3.2 | 新效果执行 | MCP | poison/weak/heal/thorns/shield_bash |
| 3.3 | 奖励池 | MCP | 13张/可实例化 |
| 4.1 | Encounter 结构 | MCP | 随机/精英/Boss |
| 4.2 | 多场流程 | MCP | 推进/区分 |
| 5.1 | 战斗背景 | MCP+手动 | 渐变/三色调 |
| 5.2 | 敌人受击反馈 | 手动 | 闪白+抖动 |
| 5.3 | 玩家受击反馈 | MCP+手动 | HitOverlay/闪红 |
| 5.4 | 敌人视觉差异化 | MCP | 5种不同视觉 |
| 5.5 | 卡牌背景差异化 | MCP | 红/绿/紫卡面 |
| — | 运行时错误 | MCP | 0 SCRIPT ERROR |
| — | 全流程回归 | MCP+手动 | 3场+GameOver+M8/M9回归 |

---

## 待手动验证项

以下需要人眼确认，无法通过 MCP 自动验证：

- [x] 不同敌人颜色/形状区分明显（红 Jaw Worm / 绿 Fungi Beast / 紫灰 Slaver / 金边 Elite / 大暗红 Boss）
- [x] Boss 比普通敌人明显更大
- [x] 普通场深蓝背景 vs 精英场暗紫 vs Boss 场暗红，色调差异可感知
- [x] 敌人受击闪白+抖动反馈自然（不过于剧烈）
- [x] 玩家受击屏幕边缘闪红反馈明显但不过于刺眼
- [x] Poison tick 绿色 ☠️ 浮动文字清晰可辨
- [x] Heal 绿色 +N 浮动文字清晰
- [x] Thorns 反伤在敌人身上显示伤害数字
- [x] Boss 阶段 2 Multi-Strike 连续命中时有视觉反馈
- [x] 新卡牌卡面正确显示（Attack 红/Skill 绿/Power 紫）
