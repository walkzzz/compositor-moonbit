# 全后端方案：去除 C FFI 依赖（已完成）

> 此计划已在 **v2.0** 完成并归档。当前项目（v4.8.0）已是纯 MoonBit 实现，无任何 C FFI 依赖，四目标 (native/wasm-gc/js/wasm) 均通过 1177 测试。

## 历史背景

本计划制定于 v1.x 时代，目标是将 native-only 的 C FFI 后端（依赖 `stb_image.h`/`stb_image_write.h`/`stb_image_resize2.h`）改造为纯 MoonBit 实现，以支持 native + wasm-gc + js 全后端。

## 完成状态

| 阶段 | 内容 | 状态 |
|------|------|------|
| 1 | 类型补全 + 子包解耦 | ✅ 已完成 |
| 2 | meta/util 解耦 | ✅ 已完成 |
| 3 | @pure 补齐核心能力（PNG/JPEG/HDR/resize 等） | ✅ 已完成 |
| 4 | 统一 API 重构（reexport.mbt 集成 @pure/@lib） | ✅ 已完成 |
| 5 | 完全移除 @core（删除 C FFI 依赖） | ✅ 已完成 |

## 当前架构

详见 [architecture.md](architecture.md)。当前为纯 MoonBit 多子包架构：

```
src/
├── types/                 # 全目标类型
├── pure/{codec,color,util}/  # 纯 MoonBit 后端（3 子包）
├── lib/                   # pure 侧统一 API + 格式分派
├── process/{color,edge,feature,filter,frequency,segment,transform}/  # 图像处理（7 子包）
├── meta/                  # 元数据
├── util/                  # 工具函数
└── reexport.mbt           # 顶层 API re-export
```

无 `core/`、`format/` 包，无 C FFI 依赖。
