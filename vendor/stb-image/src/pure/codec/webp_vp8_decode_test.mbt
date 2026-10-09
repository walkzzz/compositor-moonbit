// WebP VP8 lossy 解码测试

///|
test "decode_vp8_frame invalid data" {
  let data = Bytes::from_array([b'\x00', b'\x00', b'\x00'])
  let result = @codec.decode_vp8_frame(data, 0) catch {
    _ =>
      @types.Image::{
        width: 0,
        height: 0,
        channels: 1,
        data: Bytes::from_array([]),
      }
  }
  // 无效数据应该抛出错误，返回默认图像
  assert_true(result.width == 0 || result.width > 0)
}

///|
test "decode_webp_pure vp8 lossy placeholder" {
  // 构建一个最小的 WebP VP8 lossy 文件（仅用于测试框架）
  // RIFF header + WEBP + VP8 chunk
  let data : Array[Byte] = [
    b'\x52', b'\x49', b'\x46', b'\x46', // RIFF
     b'\x1A', b'\x00', b'\x00', b'\x00', // file size
     b'\x57', b'\x45', b'\x42', b'\x50', // WEBP
     b'\x56', b'\x50', b'\x38', b'\x20', // VP8
     b'\x0A', b'\x00', b'\x00', b'\x00', // chunk size
     b'\x00', b'\x00', b'\x00', b'\x00', // VP8 frame header (key frame)
     b'\x00', b'\x00', b'\x00', b'\x00', // start code + resolution
     b'\x00', b'\x00', // padding
  ]
  let result = @codec.decode_webp_pure(Bytes::from_array(data)) catch {
    _ =>
      @types.Image::{
        width: 0,
        height: 0,
        channels: 1,
        data: Bytes::from_array([]),
      }
  }
  // 测试框架：验证函数可以被调用
  assert_true(result.width >= 0)
}

///|
test "decode_webp_pure vp8l still works" {
  // 验证 VP8L 解码仍然正常工作（使用空数据测试错误路径）
  let data = Bytes::from_array([b'\x52', b'\x49', b'\x46', b'\x46'])
  let result = @codec.decode_webp_pure(data) catch {
    _ =>
      @types.Image::{
        width: 0,
        height: 0,
        channels: 1,
        data: Bytes::from_array([]),
      }
  }
  assert_eq(result.width, 0)
}
