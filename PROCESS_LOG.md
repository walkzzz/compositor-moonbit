# 长流程任务记录区块（固定）

> 本文件为长流程任务的权威记录区块。每一步执行"记/锁/回"三件事。
> 禁止在未确认的情况下，将群聊里的某句话当成最终决定。

---

## 一、已确认规则

| 项目         | 内容                                                                 |
| ------------ | -------------------------------------------------------------------- |
| 任务来源     | 用户指令：拉取 compositor-moonbit 仓库并继续迭代                     |
| 仓库地址     | https://github.com/walkzzz/compositor-moonbit.git                    |
| 本地路径     | /workspace/compositor-moonbit                                        |
| 语言/工具链  | MoonBit `moon 0.1.20260920`（已安装，core 已 bundle）                |
| 技能         | moonbit-development-expert（位于 .codeartsdoer/skills/ 下，已加载）  |
| 编码规范     | 见 AGENTS.md：block 风格 `///|` 分隔；`moon info && moon fmt`；`moon test` |
| 负责人       | CodeArts Agent（AI）                                                 |
| 截止时间     | 无                                                                   |
| 自动推送     | 每轮迭代完成后自动 git commit + push 到 origin/master               |
| 远程仓库     | https://github.com/walkzzz/compositor-moonbit.git（token 已配置）    |
| 迭代方向     | D+E：扩展 shared 核心功能 + 增加测试覆盖率（第 1 轮：Eraser/Fill/Blur/偏移/警告治理） |

---

## 二、冲突登记（锁）

| # | 冲突内容                                                | 来源             | 状态     | 谁有权改 |
|---|--------------------------------------------------------|------------------|----------|----------|
| 1 | 用户要求 `moonbit-development-expert` 技能，但该技能不在系统可用技能列表中 | 用户首条指令     | **已解决**（用户指引至 .codeartsdoer/skills/ 下找到并加载） | 用户     |
| 2 | MoonBit 工具链（`moon`）未安装，无法编译验证            | 环境检测         | **已解决**（已安装 moon 0.1.20260920 + 手动下载 core + bundle） | 用户/运维 |
| 3 | "继续迭代"方向未明确 | 用户首条指令     | **已解决**（用户确认 D+E：扩展 shared 核心功能 + 增加测试覆盖率） | 用户     |

---

## 三、交付回写（回）

| 环节                 | 交付物                                         | 下环依赖                                   |
|----------------------|------------------------------------------------|--------------------------------------------|
| 仓库拉取             | ✅ 仓库克隆 + 2 条提交历史                     | 确认迭代方向                               |
| 源码通读             | ✅ shared 核心 7 文件 + proton CLI + 10 测试   | 确认迭代方向                               |
| 技能加载             | ✅ moonbit-development-expert SKILL.md 已加载  | 确认迭代方向                               |
| 工具链安装           | ✅ moon 0.1.20260920 + core bundle             | 确认迭代方向                               |
| 第1轮-编码           | ✅ Eraser + Fill + Blur + 偏移 + 警告治理      | 编译验证                                   |
| 第1轮-验证           | ✅ moon check 通过，moon test 14/14 通过       | 文档治理 + 推送                            |
| 第1轮-文档           | ✅ README 更新为 Milestone 0.2，14 tests       | 自动提交推送                               |

---

## 四、项目现状快照（第 1 轮迭代后）

- **版本**：0.2.0，Milestone 0.2
- **架构**：TEA（Model-Update-View），平台无关核心 + 平台层
- **compositor_shared**（平台无关核心）：
  - `layer_model.mbt` — 数据模型：Layer(+offset_x/y)/Mask/Color/Brush/Tool(+Eraser/Fill)/Snapshot/Model + 16 种 BlendMode
  - `msg.mbt` — TEA 消息枚举（+FillAt/SetLayerOffset/AdjustBlur）
  - `update.mbt` — 纯 update 函数 + 各 handler（+eraser/fill/blur/offset）
  - `image_algo.mbt` — CPU 图像算法：画笔/橡皮擦/flood fill/Gaussian blur/16 种混合模式/flatten(带偏移)/HSL 调整
  - `undo_stack.mbt` — 撤销/重做历史（上限 50 步）
  - `project_io.mbt` — .comp 项目 JSON 编码/解码（base64 像素 + 图层偏移）
  - `extends.mbt` — derive 方法显式提升
  - `test/shared_test.mbt` — 14 个黑盒测试
- **compositor_proton**：原生 CLI 原型
- **compositor_rabbita**：Web 端 — 计划中，**尚未开始**
- **shaders/**：WGSL 着色器 — 计划中，**尚未开始**
- **vendor/stb-image**：walkzzz/image 0.6.0 STB 图像绑定

---

## 五、编译警告清单（第 1 轮迭代后）

| 警告代码 | 位置 | 说明 | 状态 |
|----------|------|------|------|
| 0029 unused_package | test/moon.pkg:2 | 测试包别名 `@S` 未使用（误报） | 保留 |
| 0025 test_unqualified_package | vendor/stb-image 多处 | vendor 代码中的非限定包导入 | 不归属本项目 |
| ~~0029~~ | ~~moon.pkg:3~~ | ~~error 未使用~~ | **已修复**（移除导入） |
| ~~0021~~ | ~~project_io.mbt:44~~ | ~~Number(value) 缺少 ..~~ | **已修复**（改为 Number(value, ..)） |

---

## 六、工具链安装记录

```bash
# 1. 安装 moon 工具链
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# → 安装到 ~/.moon/bin/，但 core 下载被 tar ownership 警告中断

# 2. 手动下载并解压 core
curl --fail --location --output ~/.moon/lib/core.tar.gz "https://cli.moonbitlang.com/cores/core-latest.tar.gz"
tar xf ~/.moon/lib/core.tar.gz --directory="$HOME/.moon/lib"

# 3. 构建 core bundle（必须步骤）
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --all
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --target wasm-gc --quiet

# 4. 更新 registry
moon update

# 5. PATH 配置
export PATH="$HOME/.moon/bin:$PATH"
```
