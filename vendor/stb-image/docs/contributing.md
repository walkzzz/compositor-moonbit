# 贡献指南

> 从 README 提取。欢迎提交 Issue 和 Pull Request！

## 📋 开发环境

```bash
# 安装 MoonBit 工具链（需 0.1.20260713+）
# 见 https://www.moonbitlang.com/download/

# 克隆并验证
git clone git@github.com:toadium/stb-image.git
cd stb-image
moon check                          # 编译检查
moon test --target native           # 运行测试（应 1203 通过）
```

## 🔧 开发流程

1. **Fork** 仓库并克隆到本地
2. **创建分支**：`git checkout -b feature/your-feature` 或 `fix/your-fix`
3. **编写代码**，遵循下方代码规范
4. **编写测试**，新功能必须有对应测试
5. **四目标验证**：
   ```bash
   moon test --target native     # 必须通过
   moon test --target wasm-gc    # 必须通过
   moon test --target js         # 必须通过
   moon test --target wasm       # 必须通过
   ```

## 📐 代码规范

| 规范 | 要求 | 示例 |
|------|------|------|
| 命名 | `snake_case` | `gaussian_blur`、`clamp_byte_v` |
| 函数分隔 | 每个顶层定义前用 `///\|` | `///\|` + 换行 + `pub fn ...` |
| 文档注释 | `pub` 函数上方添加 `///` 注释 | `/// 二值化。像素 >= threshold 设为 255` |
| 可见性 | 仅暴露必要函数为 `pub` | 内部辅助函数不加 `pub` |
| 错误处理 | 使用 `raise @types.LoadError` | `raise LoadError::DecodeFailed("msg")` |
| 测试命名 | `"函数名: 场景描述"` | `"threshold_pure: basic binarization"` |
| 解码器安全 | 入口调用 `check_dims` 校验 | `@types.check_dims(w, h, ch)` |

## 🚫 核心约束

核心约束详见 [notes.md](notes.md#核心约束)。

## 📝 提交信息格式

```
<类型>: <简述>

[可选正文，说明动机或细节]
```

**类型**：`功能`（新功能）| `修复`（bug 修复）| `文档`（文档更新）| `重构`（代码重构）| `测试`（测试补充）

**示例**：
```
功能: 新增 WebP lossless 解码器

基于 VP8L 格式规范实现，支持 8-bit RGBA 解码。
新增 42 个测试，四目标均通过。
```
