# TIFF LZW 压缩支持实现总结

## 版本
v5.5.0 (2026-09-06)

## 实现内容

### 新增函数
- `tiff_lzw_decode(data: Bytes) -> Array[Byte]`
  - 标准 LZW 解码器
  - 支持 CLEAR (256) 和 EOI (257) 码
  - 支持字典重置
  - 位级读取（LSB first）

### 修改文件
1. `src/pure/codec/tiff_codec.mbt`
   - 添加 `tiff_lzw_decode` 函数
   - 在 `decode_tiff_pure` 中添加 LZW 解压逻辑
   - 修复 strip 数据提取和拼接

2. `src/pure/codec/tiff_codec_test.mbt`
   - 新增 3 个 LZW 测试用例

### 测试结果
- 1208 测试全绿（4 个目标）
- `moon check` 无 warning
- 覆盖率：90.6%

## 技术细节

### LZW 编码格式
- 首字节：init_code_size (8-11)
- 后续字节：LZW 位流（LSB first）
- 码长：init_code_size + 1 位（直到字典满）

### TIFF 结构
```
[Header: 8 bytes]
[IFD count: 2 bytes]
[IFD entries: N × 12 bytes]
[Next IFD: 4 bytes]
[Strip data: LZW compressed]
```

### 关键修复
1. LZW 码长为 9 位（不是 8 位）
2. pixel_offset 需要包含 Next IFD 的 4 字节
3. 解压后数据顺序读取（不使用原始偏移）

## 下一步
- PackBits 压缩支持
- Deflate (ZIP) 压缩支持
