// 色调映射 16-bit/float 变体测试

///|
fn make_imgf_tm(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
  let n = w * h * ch
  let data : Array[Byte] = Array::make(n * 4, b'\x00')
  for i in 0..<n {
    let bits = val.reinterpret_as_int()
    data[i * 4] = (bits & 0xFF).to_byte()
    data[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn read_f32(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn read_u16(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
test "gamma_tonemap_f basic" {
  let img = make_imgf_tm(2, 2, 3, 1.0F)
  let out = @color.gamma_tonemap_f(img, 1.0F)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
  let v = read_f32(out.data, 0)
  assert_true(v >= 0.99F && v <= 1.01F)
}

///|
test "gamma_tonemap_f darkens" {
  let img = make_imgf_tm(2, 2, 3, 0.25F)
  let out = @color.gamma_tonemap_f(img, 2.0F)
  let v = read_f32(out.data, 0)
  // 恒定值图像归一化后输出为 1.0
  assert_true(v >= 0.99F && v <= 1.01F)
}

///|
test "gamma_tonemap_16 basic" {
  let img = make_imgf_tm(2, 2, 3, 1.0F)
  let out = @color.gamma_tonemap_16(img, 1.0F)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
  let v = read_u16(out.data, 0)
  assert_true(v >= 65000)
}

///|
test "reinhard_tonemap_f basic" {
  let img = make_imgf_tm(2, 2, 3, 1.0F)
  let out = @color.reinhard_tonemap_f(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
  let v = read_f32(out.data, 0)
  assert_true(v > 0.0F && v <= 1.0F)
}

///|
test "reinhard_tonemap_f with key" {
  let img = make_imgf_tm(2, 2, 3, 1.0F)
  let out = @color.reinhard_tonemap_f(img, key=0.5F)
  let v = read_f32(out.data, 0)
  assert_true(v > 0.0F && v <= 1.0F)
}

///|
test "reinhard_tonemap_16 basic" {
  let img = make_imgf_tm(2, 2, 3, 1.0F)
  let out = @color.reinhard_tonemap_16(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
  let v = read_u16(out.data, 0)
  assert_true(v > 0 && v <= 65535)
}

///|
test "gamma_tonemap_f zero image" {
  let img = make_imgf_tm(2, 2, 3, 0.0F)
  let out = @color.gamma_tonemap_f(img, 1.0F)
  let v = read_f32(out.data, 0)
  assert_eq(v, 0.0F)
}

///|
test "gamma_tonemap_16 zero image" {
  let img = make_imgf_tm(2, 2, 3, 0.0F)
  let out = @color.gamma_tonemap_16(img, 1.0F)
  let v = read_u16(out.data, 0)
  assert_eq(v, 0)
}
