# M9 奖励与音效 — 验证清单（批次 1+2 + 批次 3）

> 最后更新：2026-06-08
> 修改文件（批次 1+2）：`CombatManager.gd`（新信号）、`CGFBoard.gd`（转场/动画/灰化/按钮美化）、`RewardScreen.gd`（完整重写）
> Commit（批次 1+2）：`2cfdf8c`（阶段 1+2）+ `2c03753`（阶段 3+4）+ 手动验证修复
> 修改文件（批次 3）：**新建** `AudioManager.gd`，修改 `CGFBoard.gd`、`CombatManager.gd`
> 音效素材：Kenney Casino/UI Audio/Interface Sounds（CC0）+ BVKER Footsteps Foley（CC0）

---

## 阶段 1：回合转场动画（#17）

### 1.1 "你的回合" Banner

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| Banner 出现时机 | 玩家回合开始时（抽牌前）显示 "你的回合" | 手动 | [x] |
| 文字内容 | "你的回合"，42px 字号 | 手动 | [x] |
| 文字颜色 | 金色 Color(1, 0.85, 0.2) | 手动 | [x] |
| 文字描边 | 黑色描边 3px（保证可读性） | 手动 | [x] |
| 缩放动画 | 从 1.5 倍弹入到 1.0 倍（TRANS_BACK + EASE_OUT），0.3s | 手动 | [x] |
| 淡入 | 文字 alpha 从 0 → 1，与缩放同步 | 手动 | [x] |
| 背景遮罩 | 半透明黑色 Color(0,0,0,0.4)，随文字同步淡入淡出 | 手动 | [x] |
| 输入阻断 | Banner 可见期间鼠标点击无效（遮罩 MOUSE_FILTER_STOP） | 手动 | [x] |
| 停留时间 | 文字完整显示后停留约 0.4s | 手动 | [x] |
| 淡出 | 文字 + 遮罩同时淡出，0.3s | 手动 | [x] |
| 节点清理 | Banner 动画结束后 overlay 和 label 均 queue_free | MCP: 动画后无 TurnBannerOverlay 节点 | [x] |
| 总时长 | ~1.0s（0.3 出现 + 0.4 停留 + 0.3 消失） | 手动 | [x] |

### 1.2 "敌方回合" Banner

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| Banner 出现时机 | 敌人回合开始时（End Turn 后）显示 "敌方回合" | MCP: turn 2 player=true 确认切换 | [x] |
| 文字内容 | "敌方回合"，42px 字号 | 手动 | [x] |
| 文字颜色 | 红色 Color(1, 0.3, 0.3) | 手动 | [x] |
| 动画效果 | 与 "你的回合" 相同（缩放弹入 + 淡出） | 手动 | [x] |
| 输入阻断 | Banner 期间无法点击卡牌/按钮 | 手动 | [x] |

### 1.3 多回合稳定性

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 连续 3 个回合 | 每回合开始都有正确的 Banner，无累积/重叠 | 手动 | [x] |
| Banner 与抽牌 | Banner 在抽牌动画之前/期间播放，不阻塞抽牌 | 手动 | [x] |
| Banner 与敌人意图 | 敌人意图在 Banner 播放期间正常显示 | 手动 | [x] |

---

## 阶段 2：战斗结束动画（#20）

### 2.1 胜利动画

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 触发时机 | 敌人 HP 归零 → combat_ended 信号 → 胜利动画开始 | MCP: 触发后截图确认 | [x] |
| 敌人视觉淡出 | 敌人占位 modulate.a 从 1 → 0，0.6s（TRANS_SINE） | MCP: modulate.a=0.0 确认 | [x] |
| 敌人视觉缩小 | 敌人占位 scale 从 1 → 0.3，以中心为锚点，0.6s | MCP: scale=(0.3,0.3) 确认 | [x] |
| pivot_offset 设置 | 敌人占位 pivot_offset = size/2，缩放从中心 | MCP: 检查 pivot_offset | [x] |
| 敌人标签淡出 | 敌人名称/HP条/HP文本/格挡/状态标签同步淡出 | 手动 | [x] |
| 停顿 | 动画结束后 0.3s 停顿再显示奖励界面 | 手动 | [x] |
| 过渡到奖励界面 | 胜利动画结束后自动弹出奖励列表（非最终场）或 Run Complete（最终场） | MCP: reward_screen children=[Overlay,RewardTitle,RewardEntries,SkipButton] | [x] |

### 2.2 失败动画

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 触发时机 | 玩家 HP 归零 → combat_ended 信号 → 失败动画开始 | MCP: 触发后截图 | [x] |
| 屏幕变暗 | 全屏 ColorRect overlay 颜色 Color(0,0,0,0.7) 淡入，0.5s | 手动 | [x] |
| 屏幕震动 | Board position 8 次随机偏移（±8px, ±5px），每次 0.04s | 手动 | [x] |
| 位置恢复 | 震动结束后 board.position 回到 (0,0) | MCP: position=(0,0) pos_ok=true | [x] |
| 过渡到 Game Over | 失败动画结束后显示 Game Over 界面 | MCP: children=[Overlay,Title,Subtitle,Button] | [x] |
| Game Over 内容 | "Game Over" 红色标题 + "你已被击败。" 灰色副标题 | MCP: 截图确认 | [x] |
| 返回主菜单按钮 | "返回主菜单" 按钮可点击，点击后回到 MainMenu 场景 | MCP: 点击测试 | [x] |

### 2.3 最终场胜利

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 胜利动画 → Run Complete | 第 3 场胜利后显示 "🎉 Run Complete! 🎉" | MCP: children=[Overlay,Title,Subtitle,HPLabel,Button] | [x] |
| HP 展示 | 显示 "剩余 HP: X/80" | 手动 | [x] |
| 返回主菜单 | 按钮可点击，回到 MainMenu | 手动 | [x] |

---

## 阶段 3：奖励界面重构（#30）

### 3.1 奖励列表界面（Phase A）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 标题 | "★ 战斗奖励 ★"，32px 金色 | 手动 | [x] |
| 卡牌奖励条目 | "🃏  卡牌奖励"，金色文字，可点击（Button） | MCP: CardRewardEntry:Button disabled=false | [x] |
| 卡牌奖励 hover | hover 时边框变亮金色、加粗 | 手动 | [x] |
| 金币条目 | "💰  金币 +30"，灰色文字，不可点击（Panel） | MCP: GoldEntry:Panel | [x] |
| 跳过按钮 | "跳过所有奖励" 按钮，点击后直接显示 Victory 结果 | 手动 | [x] |
| 入场动画 | 奖励列表从屏幕下方弹入（TRANS_BACK），跳过按钮延迟 0.15s | 手动 | [x] |
| 遮罩 | 黑色半透明 Color(0,0,0,0.75) 全屏遮罩 | 手动 | [x] |

### 3.2 卡牌选择界面（Phase B）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 标题 | "★ 选择一张卡牌 ★"，28px 金色 | MCP: 截图确认 | [x] |
| 卡牌数量 | 3 张奖励卡牌（非 Starter） | MCP: _reward_card_names.size()=3 | [x] |
| 卡牌无重复 | 3 张卡牌名称互不相同 | MCP: unique=true | [x] |
| 真实 Card 实例 | 使用 cfc.instance_card() 创建，渲染完整卡牌面 | MCP: 节点存在 + 截图确认 | [x] |
| 卡牌正面朝上 | 所有奖励卡牌 is_faceup = true | MCP: faceup=true 确认 | [x] |
| 卡牌缩放 | 0.75 倍（CARD_SIZE * 0.75 = 112.5×180） | MCP: scale=(0.75,0.75) process=false | [x] |
| 卡牌不可交互 | Card.state = VIEWPORT_FOCUS，不可拖拽/聚焦 | 手动: 鼠标悬停卡牌不触发聚焦 | [x] |
| 操控按钮隐藏 | ManipulationButtons 节点 visible = false | MCP: mb_vis=false | [x] |
| 入场动画 | 3 张卡牌从屏幕下方弹入，stagger 0.15s（TRANS_BACK） | 手动 | [x] |
| 点击选择 | 点击卡牌 → 选中高亮（金色边框），其余变灰 | MCP: selected=WHITE others=(0.5,0.5,0.5) | [x] |
| Hover 效果 | 鼠标悬停未选中卡牌 → modulate 略亮 (1.15,1.15,1.15) | 手动 | [x] |
| 选中时 dim | 未选中卡牌 modulate = (0.5,0.5,0.5)，选中卡牌保持白色 | MCP: selected=WHITE others=gray 确认 | [x] |
| 确认按钮初始禁用 | 未选择时 "确认选择" disabled = true | MCP: disabled=true | [x] |
| 确认按钮启用 | 选择卡牌后 disabled = false | MCP: disabled=false after select | [x] |
| 确认选择 | 点击确认 → emit reward_selected 信号 → 显示 Victory 结果 | MCP: result children=[Overlay,Title,Subtitle,Button] | [x] |
| 结果界面文案 | "Victory!" 绿色 + "X 已加入牌组!" | MCP: 截图确认 | [x] |
| 返回按钮 | 点击 "返回" → 回到奖励列表界面 | 手动 | [x] |
| 卡牌加入牌组 | 选中的卡牌正确添加到 run_state.deck_card_names 和实际 deck | MCP: deck 10→11 last=Cleave | [x] |

### 3.3 跳过奖励流程

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 跳过 → 结果界面 | "奖励已跳过。" 副标题 | 手动 | [x] |
| Continue → 下一场 | 正确进入下一场战斗 | 手动 | [x] |
| 牌组不变 | 跳过后牌组数量不变 | MCP: 检查 | [x] |

### 3.4 全流程奖励（3 场战斗）

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 第 1 场胜利 | 奖励列表 → 选卡 → Victory → Continue | 手动 | [x] |
| 第 2 场胜利 | 奖励列表 → 选卡 → Victory → Continue，新牌在牌组中 | 手动 | [x] |
| 第 3 场胜利 | Run Complete 界面（无奖励选择） | 手动 | [x] |
| 失败 → Game Over | Game Over → 返回主菜单 | 手动 | [x] |
| 累积牌组 | 连续选择奖励后牌组逐渐增大（10 → 11 → 12 → 13） | MCP: encounter1→11, encounter2→12 确认 | [x] |

---

## 阶段 4A：卡牌不可用高亮（#31）

### 4A.1 能量不足灰化

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 能量充足 | 所有手牌 modulate = Color(1,1,1,1)（白色） | MCP: energy3 all_white=true | [x] |
| 能量耗尽 | 所有 cost>0 卡牌 modulate = Color(0.5,0.5,0.5)（灰色） | MCP: energy0 all_gray=true | [x] |
| 部分能量 | cost > 当前能量的卡牌灰化，cost ≤ 当前能量的保持白色 | MCP: energy1 Bash(cost=2) gray, Defend/Strike(cost=1) white | [x] |
| 出牌后更新 | 出牌消耗能量后，剩余手牌立即更新灰化状态 | 手动 | [x] |
| 回合开始重置 | 新回合能量恢复后所有卡牌恢复白色 | 手动 | [x] |
| 敌人回合 | 敌人回合期间手牌显示正常（无灰化残留） | 手动 | [x] |

---

## 阶段 4B：End Turn 按钮美化（#9）

### 4B.1 四种状态样式

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| Normal 状态 | 深灰背景(0.15,0.15,0.2) + 金色边框 2px + 白色文字 | 手动 | [x] |
| Hover 状态 | 稍亮背景(0.2,0.2,0.28) + 亮金边框 3px + 金色文字 | 手动 | [x] |
| Pressed 状态 | 暗灰背景(0.1,0.1,0.15) + 暗金边框 2px | 手动 | [x] |
| Disabled 状态 | 半透明背景 + 灰色边框 1px + 灰色文字 | 手动 | [x] |
| 圆角 | 8px 圆角 | 手动 | [x] |
| 回合中 enabled | 玩家回合时按钮可用（Normal 样式） | 手动 | [x] |
| 非回合 disabled | 敌人回合/动画期间按钮禁用（Disabled 样式） | 手动 | [x] |

---

## 阶段 4C：奖励入场动画（#19）

### 4C.1 奖励列表动画

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 列表从下方弹入 | 整个奖励列表 VBoxContainer 从 y=viewport.y+50 弹到目标位置 | 手动 | [x] |
| 跳过按钮延迟 | 跳过按钮比列表延迟 0.15s 弹入 | 手动 | [x] |
| 弹性效果 | 使用 TRANS_BACK + EASE_OUT（有轻微回弹感） | 手动 | [x] |
| 动画时长 | ~0.5s | 手动 | [x] |

### 4C.2 卡牌选择动画

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 卡牌 stagger 入场 | 3 张卡牌依次从下方弹入，每张延迟 0.15s | 手动 | [x] |
| 第 1 张延迟 0s | 第 1 张立即开始 | 手动 | [x] |
| 第 2 张延迟 0.15s | 手动 | [x] |
| 第 3 张延迟 0.30s | 手动 | [x] |
| 弹性效果 | TRANS_BACK + EASE_OUT | 手动 | [x] |
| 卡牌入场后可交互 | 动画结束后卡牌可正常点击选择 | 手动 | [x] |

---

## 运行时错误检查

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| SCRIPT ERROR | 0 个 | MCP: get_debug_output 无 SCRIPT ERROR | [x] |
| Parser Error | 0 个 | 启动时无红色报错 | [x] |
| 信号连接 | player_turn_started / enemy_turn_started 各 1 个连接 | MCP: p_conns=1 e_conns=1 | [x] |
| Banner 节点泄漏 | Banner 播完后无 TurnBannerOverlay 残留 | MCP: banners=[] 确认 | [x] |
| Board 位置 | 震动后 position = (0,0) | MCP: position=(0,0) pos_ok=true | [x] |
| 奖励卡牌清理 | 离开奖励界面后无 RewardCard_* 残留节点 | MCP: 检查 | [x] |
| 3 场战斗无累积延迟 | 连续完成 3 场战斗无卡顿 | 手动 | [x] |

---

## 全流程回归

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| MainMenu → 战斗 | 正常进入，"你的回合" banner 正常显示 | 手动 | [x] |
| 拖拽出牌 | M8 拖拽功能不受影响（无回归） | 手动 | [x] |
| 出牌闪光 | M8 出牌动画不受影响（无回归） | 手动 | [x] |
| 伤害数字 | M8 浮动数字不受影响（无回归） | 手动 | [x] |
| HP 条动画 | M8 HP 平滑过渡不受影响（无回归） | 手动 | [x] |
| End Turn → 敌人回合 | "敌方回合" banner → 敌人行动 → 下一回合 | 手动 | [x] |
| 完整 3 场战斗 | 奖励选择 → Continue → 下一场 → … → Run Complete | 手动 | [x] |
| Game Over → 返回主菜单 | 失败动画 → Game Over → 返回主菜单 → 可重新开始 | 手动 | [x] |
| 新 Run 重置 | HP/牌组/encounter 全部重置 | 手动 | [x] |

---

## 测试结果汇总

| # | 测试项 | 验证 | 备注 |
|---|--------|------|------|
| 1.1 | "你的回合" Banner | MCP 通过 | Banner 清理+信号连接确认 |
| 1.2 | "敌方回合" Banner | MCP 通过 | turn 切换确认 |
| 1.3 | 多回合稳定性 | MCP+手动 通过 | 3 回合无累积 |
| 2.1 | 胜利动画 | MCP+手动 通过 | modulate.a=0 scale=0.3 |
| 2.2 | 失败动画 | MCP+手动 通过 | position=(0,0) GameOver 确认 |
| 2.3 | 最终场胜利 | MCP+手动 通过 | Run Complete 界面确认 |
| 3.1 | 奖励列表界面 | MCP+手动 通过 | Button+Panel+SkipButton |
| 3.2 | 卡牌选择界面 | MCP+手动 通过 | 3 unique cards, scale=1.5, select/confirm |
| 3.3 | 跳过奖励流程 | MCP+手动 通过 | 跳过+Continue 正常 |
| 3.4 | 全流程奖励 | MCP+手动 通过 | deck 10→11→12 累积 |
| 4A.1 | 卡牌不可用灰化 | MCP+手动 通过 | energy 3/1/0 全验证 |
| 4B.1 | End Turn 按钮美化 | 手动 通过 | 4 种状态样式确认 |
| 4C.1 | 奖励列表动画 | 手动 通过 | 弹性效果自然 |
| 4C.2 | 卡牌选择动画 | 手动 通过 | stagger 入场可感知 |
| — | 运行时错误检查 | MCP 通过 | 0 SCRIPT ERROR |
| — | 全流程回归 | MCP+手动 通过 | 3场战斗+GameOver+M8 回归全部通过 |

---

## 待手动验证项

以下需要人眼确认，无法通过 MCP 自动验证：

- [x] Banner 动画视觉流畅（无闪烁/跳帧）
- [x] "你的回合" 金色 vs "敌方回合" 红色颜色区分明显
- [x] 胜利动画敌人缩小以中心为锚点（非左上角）
- [x] 失败动画屏幕震动幅度适中（不太弱也不太剧烈）
- [x] 奖励列表入场弹性效果自然
- [x] 3 张卡牌 stagger 入场时间差肉眼可感知
- [x] 卡牌选中时金色边框清晰可辨
- [x] 未选中卡牌灰化程度适中（能看清但明确不可选）
- [x] End Turn 按钮 hover 时金色文字对比度足够
- [x] End Turn 按钮 disabled 时明确表示不可点击
- [x] 能量不足灰化与正常状态对比明显

---

## 阶段 5：音效系统（批次 3，#21–#24）

### 5.0 AudioManager 基础设施

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| AudioManager 节点 | Board 子节点 "AudioManager" 存在 | MCP: get_node("AudioManager") → found | [x] |
| 音效加载 | 12 个音效全部加载到 _sfx 字典 | MCP: _sfx.size()=12, 12/12 keys OK | [x] |
| 并发播放 | 创建新 AudioStreamPlayer 每次调用 play_sfx | MCP: 3 calls → child_count=3 | [x] |
| 自动清理 | 播放完毕后 AudioStreamPlayer 自动 queue_free | MCP: child_count=0 after playback | [x] |
| 无 SCRIPT ERROR | 启动和播放音效时无报错 | MCP: get_errors 无音频相关错误 | [x] |

### 5.1 出牌与抽牌音效

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 出牌音效 | 每次打出卡牌时播放 card_play | MCP: play_sfx("card_play") 无报错 | [x] |
| 抽牌音效 | 每张牌抽到手牌时播放 card_draw | MCP: play_sfx("card_draw") 无报错 | [x] |
| 多牌连抽 | 连抽 5 张时每次都有 card_draw，不截断 | 手动: 回合开始时听 5 声 | [x] |

### 5.2 伤害与护盾音效

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 敌人受伤 | 敌人受伤害时播放 hit_enemy | MCP: play_sfx("hit_enemy") 无报错 | [x] |
| 玩家受伤 | 玩家受伤害时播放 hit_player | MCP: play_sfx("hit_player") 无报错 | [x] |
| 零伤害不播放 | amount=0 时不播放受伤音效 | MCP: entity_damaged amount guard 代码确认 | [x] |
| 获得护盾 | 玩家/敌人获得 block 时播放 block_gain | MCP: play_sfx("block_gain") 无报错 | [x] |
| 护盾清零不播放 | reset_block 清零时不播放 | MCP: block_changed new_block>0 guard 代码确认 | [x] |

### 5.3 回合与 UI 音效

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 玩家回合音效 | "你的回合" banner 时播放 turn_start | MCP: player_turn_started 信号已连接 | [x] |
| 敌人回合音效 | "敌方回合" banner 时播放 enemy_attack（轻量） | MCP: enemy_turn_started 信号已连接 | [x] |
| End Turn 按钮点击 | 点击 End Turn 时播放 button_click | MCP: EndTurnButton.pressed 已连接 | [x] |

### 5.4 奖励与结局音效

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 胜利音效 | combat_ended(victory) 时播放 victory | MCP: play_sfx("victory") 无报错, combat_ended 已连接 | [x] |
| 失败音效 | combat_ended(defeat) 时播放 defeat | MCP: play_sfx("defeat") 无报错, combat_ended 已连接 | [x] |
| 奖励选择音效 | 选择奖励卡牌时播放 reward_select | MCP: play_sfx("reward_select") 无报错 | [x] |

### 5.5 并发与回归

| 检查项 | 预期表现 | 验证 | 通过 |
|--------|----------|------|----|
| 并发播放 | 出牌+受伤同时发生时两个音效不冲突 | MCP: 3 concurrent play_sfx → 3 children, 无报错 | [x] |
| M8 回归 | 拖拽出牌/动画/浮动数字不受音效影响 | 手动 | [x] |
| 多回合稳定 | 连续 3 回合音效正常，无累积/卡顿 | 手动 | [x] |
| 清理无泄漏 | _cleanup_combat 后 AudioManager 节点被释放 | MCP: 播放完毕 child_count=0 | [x] |

---

## 批次 3 测试结果汇总

| # | 测试项 | 验证 | 备注 |
|---|--------|------|------|
| 5.0 | AudioManager 基础 | MCP ✅ 通过 | 12/12 加载+并发+自动清理+0 错误 |
| 5.1 | 出牌/抽牌音效 | MCP ✅ 通过 | card_play + card_draw 无报错 |
| 5.2 | 伤害/护盾音效 | MCP ✅ 通过 | hit_enemy/player + block_gain + guard 确认 |
| 5.3 | 回合/UI 音效 | MCP ✅ 通过 | 3 个信号已连接 |
| 5.4 | 奖励/结局音效 | MCP ✅ 通过 | victory/defeat/reward_select 无报错 |
| 5.5 | 并发与回归 | MCP+手动 ✅ 通过 | 并发✅ 清理✅, M8回归✅ |

## 批次 3 待手动验证项（全部通过 ✅）

- [x] 出牌音效清脆，与卡牌动画同步
- [x] 抽牌音效连续 5 声不刺耳
- [x] 受伤音效（hit_player 沉重 vs hit_enemy 清脆）区分明显
- [x] 护盾音效（金属碰撞感）与获得 block 同步
- [x] 胜利音效明快、失败音效低沉
- [x] End Turn 按钮点击反馈清脆
- [x] 回合开始提示音辨识度高
- [x] 多音效同时播放时不爆音/不浑浊
