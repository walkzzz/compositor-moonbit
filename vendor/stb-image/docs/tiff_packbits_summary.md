# TIFF PackBits 压缩支持实现总结

## 版本
v5.6.0 (2026-09-06)

## 实现内容

### 新增函数
- `tiff_packbits_decode(data: Bytes) -> Array[Byte]`
  - 标准 PackBits RLE 解码器
  - count=0: 字面量（复制 1 字节）
  - count=1-127: 复制 n+1 个字节
  - count=-127 到 -1: 重复下一个字节 -n+1 次
  - count=-128: 扩展模式

### 修改文件
1. `src/pure/codec/tiff_codec.mbt`
   - 添加 `tiff_packbits_decode` 函数
   - 在 `decode_tiff_pure` 中添加 PackBits 解压逻辑
   - 更新压缩校验从 "仅支持 1/5" 到 "1/5/32773"

2. `src/pure/codec/tiff_codec_test.mbt`
   - 新增 3 个 PackBits 测试用例

### 测试结果
- 1211 测试全绿（4 个目标）
- `moon check` 无 warning
- 覆盖率：91.2%

## 技术细节

### PackBits 编码规则
- 单个字节或不同序列：count=0 + 字节
- 连续 n 个相同字节 (2<=n<=128)：count=1-n + 字节值
- 超过 128 字节：使用扩展模式

### 关键实现
```moonbit
fn tiff_packbits_decode(data : Bytes) -> Array[Byte] {
  while pos < len {
    let count = data[pos].to_int()
    pos += 1
    
    if count == 128 { /* 扩展模式 */ }
    else if count >= 0 { /* 字面量 */ }
    else { /* 重复 */ }
  }
}
```

## 下一步
- Deflate (ZIP) 压缩支持
- 考虑实现压缩后的写入功能
