# 环境准备指南

> 本文档记录在 Linux/aarch64 环境下从零搭建 MoonBit 开发环境的完整步骤。
> 包含工具链安装、core 标准库修复、registry 配置和常见问题解决方案。

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Linux (aarch64 / x86_64) |
| 架构 | `uname -m` → `aarch64` 或 `x86_64` |
| git | 已安装 |
| curl | 已安装 |
| 容器环境 | tar ownership 警告可忽略 |

---

## 步骤 1：安装 MoonBit 工具链

```bash
# 官方安装脚本（Linux & macOS）
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

安装后工具链位于 `~/.moon/bin/`：

| 工具 | 说明 |
|------|------|
| `moon` | 构建系统 + 包管理器 |
| `moonc` | 编译器 |
| `moonrun` | 运行时 |
| `moonfmt` | 格式化工具 |
| `mooninfo` | 接口生成工具 |
| `mooncake` | 包管理 |
| `moondoc` | 文档生成 |

### 配置 PATH

```bash
export PATH="$HOME/.moon/bin:$PATH"
```

建议写入 `~/.bashrc` 或 `~/.zshrc` 持久化。

### 验证安装

```bash
moon version
# 预期输出：
# moon 0.1.20260920 (914d7da 2026-09-20)
# Feature flags enabled: rr_moon_mod,rr_moon_pkg
```

---

## 步骤 2：修复 core 标准库（关键！）

### 问题

官方安装脚本在容器环境中会因 `tar` 的 ownership 警告中断，导致：
1. core 标准库**未下载**
2. core bundle**未构建**

表现为 `moon check` 报错：
```
Error: Cannot inject the standard library `moonbitlang/core`: Cannot load the core file
```

### 解决方案

#### 2.1 手动下载 core

```bash
# 下载 core 标准库压缩包
curl --fail --location --output ~/.moon/lib/core.tar.gz \
  "https://cli.moonbitlang.com/cores/core-latest.tar.gz"
```

#### 2.2 解压 core

```bash
# 解压到 lib 目录（忽略 ownership 警告）
rm -rf ~/.moon/lib/core
tar xf ~/.moon/lib/core.tar.gz --directory="$HOME/.moon/lib"
```

> **注意：** tar 会输出大量 `Cannot change ownership to uid 1001, gid 1001: Invalid argument` 警告。
> 这是容器环境的正常现象，**不影响功能**，可安全忽略。

#### 2.3 验证 core 解压

```bash
ls ~/.moon/lib/core/moon.mod
# 预期输出：/workspace/.moon/lib/core/moon.mod

head -5 ~/.moon/lib/core/moon.mod
# 预期输出：
# name = "moonbitlang/core"
# version = "0.10.14+7d59c7ec9"
```

#### 2.4 构建 core bundle（必须步骤）

```bash
# 构建 all targets bundle
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --all
# 预期输出：Finished. moon: ran 328 tasks, now up to date

# 构建 wasm-gc target bundle
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --target wasm-gc --quiet
# 预期输出：Finished. moon: ran 5 tasks, now up to date
```

> **关键：** 如果跳过这一步，`moon check` 会报错：
> `Sys_error(".../core/_build/wasm/release/bundle/prelude/prelude.mi: No such file or directory")`

---

## 步骤 3：更新 Registry

```bash
moon update
# 预期输出：
# Registry index cloned successfully
# Symbols updated successfully
```

Registry 缓存位于 `~/.moon/registry/`：
- `index/` — 包索引（Git 仓库）
- `symbols/` — 符号缓存
- `cache/` — 下载的包缓存

---

## 步骤 4：验证工具链

### 创建测试项目

```bash
cd /tmp
moon new testproject
cd testproject
moon check
# 预期：无错误

moon run src/main
# 预期：Hello, world!
```

### 清理测试项目

```bash
rm -rf /tmp/testproject
```

---

## 步骤 5：克隆并验证目标项目

```bash
# 克隆项目
git clone https://github.com/walkzzz/compositor-moonbit.git
cd compositor-moonbit

# 编译检查
moon check
# 预期：通过（仅有警告）

# 运行测试
moon test src/compositor_shared/test --target native
# 预期：Total tests: 10, passed: 10, failed: 0.
```

---

## 常见问题

### Q1: `Cannot load the core file`

**原因：** core 标准库未下载或未解压。

**解决：** 执行步骤 2.1-2.4。

### Q2: `prelude.mi: No such file or directory`

**原因：** core 已解压但未构建 bundle。

**解决：** 执行步骤 2.4（`moon bundle`）。

### Q3: `module was not found in the registry`

**原因：** registry 未更新。

**解决：** 执行 `moon update`。

### Q4: `Permission denied` 执行 moon

**原因：** 二进制文件缺少执行权限。

**解决：**
```bash
chmod +x ~/.moon/bin/moon ~/.moon/bin/moonc ~/.moon/bin/moonrun \
  ~/.moon/bin/moonfmt ~/.moon/bin/mooninfo ~/.moon/bin/mooncake \
  ~/.moon/bin/moondoc
```

### Q5: tar ownership 警告

**现象：**
```
tar: ./core/...: Cannot change ownership to uid 1001, gid 1001: Invalid argument
```

**说明：** 容器环境正常现象，文件已正确解压，**不影响功能**。

### Q6: 架构不匹配

**现象：** moon 二进制是 ARM aarch64，但系统是 x86_64（或反之）。

**解决：** 安装脚本会自动检测架构。如需手动下载：
```bash
# aarch64
curl -fsSL https://cli.moonbitlang.com/binaries/latest/moonbit-aarch64-linux.tar.gz

# x86_64
curl -fsSL https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz
```

---

## 工具链命令速查

| 命令 | 说明 |
|------|------|
| `moon check` | 类型检查（不生成目标文件） |
| `moon build --target native` | 构建原生目标 |
| `moon build --target wasm` | 构建 WASM 目标 |
| `moon build --target js` | 构建 JS 目标 |
| `moon run <target>` | 运行主包 |
| `moon test` | 运行测试 |
| `moon test --target native` | 运行原生测试 |
| `moon fmt` | 格式化代码 |
| `moon info` | 生成 .mbti 接口文件 |
| `moon clean` | 清理构建缓存 |
| `moon update` | 更新 registry |
| `moon add <pkg>` | 添加依赖 |
| `moon install <pkg>` | 安装包 |
| `moon doc` | 生成文档 |
| `moon version` | 查看版本 |
| `moon version --all` | 查看所有组件版本 |

---

## 环境信息快照

```
OS: Linux (aarch64)
moon: 0.1.20260920 (914d7da 2026-09-20)
moonc: v0.10.14+7d59c7ec9 (2026-09-18)
moonrun: 0.1.20260920 (914d7da 2026-09-20)
core: 0.10.14+7d59c7ec9
Feature flags: rr_moon_mod, rr_moon_pkg
```

---

## 一键安装脚本

```bash
#!/bin/bash
set -e

echo "=== Installing MoonBit toolchain ==="
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"

echo "=== Fixing core standard library ==="
curl --fail --location --output ~/.moon/lib/core.tar.gz \
  "https://cli.moonbitlang.com/cores/core-latest.tar.gz"
rm -rf ~/.moon/lib/core
tar xf ~/.moon/lib/core.tar.gz --directory="$HOME/.moon/lib" 2>/dev/null || true

echo "=== Building core bundle ==="
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --all
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --target wasm-gc --quiet

echo "=== Updating registry ==="
moon update

echo "=== Verifying ==="
moon version
echo "=== Done ==="
```
