# M7 游戏流程串联 — 验证清单

> 最后更新：2026-06-06
> 新增文件：`RunState.gd`（跨战斗运行状态管理）
> 修改文件：`CGFBoard.gd`（run 生命周期、encounter 切换）、`CombatEntity.gd`（initial_hp 参数）、`RewardScreen.gd`（continue_run 信号、Run Complete 界面）

---

## 流程概览

```
MainMenu → CGFMain (Board)
             │
             ├─ _start_run() → RunState(HP=80, 10 cards)
             ├─ Encounter 0: Jaw Worm 42HP, Battle 1/3
             ├─ 胜利 → RewardScreen(非最终) → 选卡/Skip → Continue
             ├─ Encounter 1: Jaw Worm 55HP, Battle 2/3
             ├─ 胜利 → RewardScreen(非最终) → 选卡/Skip → Continue
             ├─ Encounter 2: Jaw Worm Elite 70HP, Battle 3/3
             ├─ 胜利 → Run Complete 界面 → 返回主菜单
             │
             └─ 任意战斗失败 → Game Over → 返回主菜单
```

---

## 1. Run State 初始化

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| RunState 创建 | `run_state` 非 null | `board.run_state != null` | ✅ |
| 初始 HP | player_hp=80, player_max_hp=80 | MCP 确认 | ✅ |
| 起手牌组 | 10 张：5×Strike + 4×Defend + 1×Bash | `deck_card_names.size() == 10` | ✅ |
| 初始 encounter | current_encounter=0 | MCP 确认 | ✅ |

---

## 2. Encounter 1 启动

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| 进度标签 | "Battle 1/3" 显示在顶部中央 | `_encounter_label.text == "Battle 1/3"` | ✅ |
| 敌人名称 | Jaw Worm | `enemy.display_name == "Jaw Worm"` | ✅ |
| 敌人 HP | 42/42 | MCP 确认 | ✅ |
| 玩家 HP | 80/80 | MCP 确认 | ✅ |
| is_final | false | MCP 确认 | ✅ |

---

## 3. Encounter 1 胜利 → 奖励界面

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| combat_result | "victory" | MCP 确认 | ✅ |
| HP 保存 | run_state.player_hp=80 | MCP 确认 | ✅ |
| RewardScreen 出现 | 非最终场胜利，显示奖励选择 | `_reward_screen != null` | ✅ |
| 奖励卡来自非 Starter | 3 张来自奖励池 | Bloodletting, Heavy Blow, Inflame | ✅ |
| 奖励卡信号 | has signal "continue_run" | MCP 确认 | ✅ |

---

## 4. 奖励卡选择 → Continue

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| 选卡加入牌组 | deck_card_names.size() → 11 | 选 Inflame，size=11 | ✅ |
| 牌组末尾是新卡 | deck_card_names[-1] == "Inflame" | MCP 确认 | ✅ |
| Continue 按钮 | 胜利结果画面显示 "Continue" | MCP 确认 | ✅ |
| Continue 信号 | emit continue_run → _advance_to_next_encounter | MCP 确认 | ✅ |

---

## 5. Encounter 2 启动（HP 继承）

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| encounter 推进 | current_encounter=1 | MCP 确认 | ✅ |
| 进度标签 | "Battle 2/3" | `_encounter_label.text` | ✅ |
| 敌人变更 | Jaw Worm HP 55/55 | MCP 确认 | ✅ |
| 玩家 HP 继承 | 80/80（Encounter 1 无伤） | MCP 确认 | ✅ |
| max_hp 不变 | player_max_hp=80 | MCP 确认 | ✅ |
| 牌组持久化 | 11 张（含 Inflame） | MCP 确认 | ✅ |
| is_final | false | MCP 确认 | ✅ |

---

## 6. Encounter 2 胜利（受伤状态）→ Skip → Continue

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| 玩家受伤 | player.take_damage(25) → HP=55 | MCP 确认 | ✅ |
| combat_result | "victory" | MCP 确认 | ✅ |
| Skip 奖励 | 牌组保持 11 张 | MCP 确认 | ✅ |
| HP 保存 | run_state.player_hp=55 | MCP 确认 | ✅ |

---

## 7. Encounter 3 启动（HP 继承 + 最终场）

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| encounter 推进 | current_encounter=2 | MCP 确认 | ✅ |
| 进度标签 | "Battle 3/3" | MCP 确认 | ✅ |
| 敌人变更 | Jaw Worm Elite HP 70/70 | MCP 确认 | ✅ |
| 玩家 HP 继承 | 55/80（无回复） | MCP 确认 | ✅ |
| is_final | true | MCP 确认 | ✅ |
| 牌组持久化 | 11 张 | MCP 确认 | ✅ |

---

## 8. 最终场胜利 → Run Complete 界面

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| 不显示奖励界面 | 直接进入 Run Complete（非 RewardScreen） | MCP 确认 | ✅ |
| 标题文字 | "🎉 Run Complete! 🎉" | MCP 确认 | ✅ |
| 副标题 | "You defeated all 3 encounters!" | MCP 确认 | ✅ |
| HP 显示 | "Remaining HP: 45/80"（80-25-10=45） | MCP 确认 | ✅ |
| 返回按钮 | "Return to Main Menu" | MCP 确认 | ✅ |

---

## 9. Game Over（中途死亡）

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| 玩家死亡 | combat_result="defeat" | MCP 确认 | ✅ |
| Game Over 界面 | "Game Over" 红色标题 | MCP 确认 | ✅ |
| 副标题 | "You have been defeated." | MCP 确认 | ✅ |
| 返回按钮 | "Return to Main Menu" | MCP 确认 | ✅ |

---

## 10. 新 Run 重置

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| HP 重置 | 80/80 | MCP 确认 | ✅ |
| encounter 重置 | current_encounter=0 | MCP 确认 | ✅ |
| 牌组重置 | 10 张（不含之前 run 的奖励卡） | MCP 确认 | ✅ |

---

## 11. 运行时错误检查

| 检查项 | 预期表现 | MCP 验证 | ✅ |
|--------|----------|----------|----|
| SCRIPT ERROR | 0 个 | get_errors 返回零 | ✅ |
| Parser Error | 0 个 | 干净退出 | ✅ |
| Debugger Break | 0 个 | 干净退出 | ✅ |

---

## 测试结果汇总

| # | 测试项 | MCP 验证 | 手动验证 | 备注 |
|---|--------|----------|----------|------|
| 1 | Run State 初始化 | ✅ | ✅ | |
| 2 | Encounter 1 启动 | ✅ | ✅ | Jaw Worm 42HP |
| 3 | Encounter 1 胜利 → 奖励 | ✅ | ✅ | |
| 4 | 奖励卡选择 → Continue | ✅ | ✅ | Inflame 加入 |
| 5 | Encounter 2 启动 | ✅ | ✅ | Jaw Worm 55HP, HP 继承 |
| 6 | Encounter 2 胜利（受伤）| ✅ | ✅ | Skip 奖励 |
| 7 | Encounter 3 启动 | ✅ | ✅ | Jaw Worm Elite 70HP, HP 55/80 |
| 8 | Run Complete 界面 | ✅ | ✅ | HP 45/80 |
| 9 | Game Over | ✅ | ✅ | 中途死亡 |
| 10 | 新 Run 重置 | ✅ | ✅ | HP/牌组/encounter 全部重置 |
| 11 | 运行时错误检查 | ✅ | ✅ | 零 SCRIPT ERROR |

---

## 待手动验证项

以下需要人眼确认，无法通过 MCP 自动验证：

- [x] Encounter 切换时 UI 无闪烁/残留
- [x] "Battle X/3" 标签位置居中、文字清晰
- [x] Encounter 2/3 开始时卡牌洗牌动画正常
- [x] Run Complete 界面金色标题 + 绿色副标题视觉正确
- [x] Game Over 界面红色标题视觉正确
- [x] 连续快速点击 Continue 无异常行为
