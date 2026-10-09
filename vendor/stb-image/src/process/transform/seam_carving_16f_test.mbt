// seam_carving 16-bit/float 测试

///|
test "compute_energy_16 basic" {
  let w = 8
  let h = 8
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let energy = @transform.compute_energy_16(img)
  assert_eq(energy.length(), w * h)
}

///|
test "compute_energy_f basic" {
  let w = 8
  let h = 8
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let energy = @transform.compute_energy_f(img)
  assert_eq(energy.length(), w * h)
}

///|
test "seam_carve_resize_16 shrink" {
  let w = 16
  let h = 16
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let out = @transform.seam_carve_resize_16(img, 12, 12)
  assert_eq(out.width, 12)
  assert_eq(out.height, 12)
  assert_eq(out.channels, ch)
}

///|
test "seam_carve_resize_f shrink" {
  let w = 16
  let h = 16
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let out = @transform.seam_carve_resize_f(img, 12, 12)
  assert_eq(out.width, 12)
  assert_eq(out.height, 12)
  assert_eq(out.channels, ch)
}
