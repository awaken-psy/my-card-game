# Game Development Workflow

## 双目录结构

| 目录 | 分支 | 用途 |
|------|------|------|
| `../godot-card-game-framework/` | `pr194-godot4-conversion` | 框架 PR，保持干净 |
| `./` (本目录) | `game/my-card-game` | 游戏开发 |

## 工作流程

### 日常游戏开发
直接在本目录工作，修改 `src/custom/` 中的游戏代码。

### 发现框架 Bug
1. 在本目录（game 分支）修复 `src/core/` 中的问题
2. 提交到 game 分支
3. cherry-pick 到框架 PR 分支：
   ```bash
   cd ../godot-card-game-framework
   git cherry-pick <commit-hash>
   ```

### 同步框架更新
```bash
cd ../godot-card-game-framework
# 框架分支有更新后：
cd ../godot-card-game-framework-game
git merge pr194-godot4-conversion
```

## 文件归属

### 只属于游戏（不进 PR）
- `src/custom/` 下所有文件（卡牌定义、场景、脚本）
- `assets/` 下的游戏素材
- `project.godot`（项目名、主场景）

### 属于框架（cherry-pick 进 PR）
- `src/core/` 下的框架核心代码
- `addons/gut/` 测试框架
- `tests/` 测试文件

## 注意事项
- 不要在框架目录修改 `src/custom/`
- 不要在游戏目录修改 `tests/`（除非是游戏专属测试）
