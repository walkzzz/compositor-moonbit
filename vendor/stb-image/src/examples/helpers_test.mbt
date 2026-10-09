// 示例通用辅助函数：构造测试用图像

///|
let test_4x4_red_png : Bytes = Bytes::from_array([
  b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', b'\x00',
  b'\x00', b'\x00', b'\x0D', b'\x49', b'\x48', b'\x44', b'\x52', b'\x00', b'\x00',
  b'\x00', b'\x04', b'\x00', b'\x00', b'\x00', b'\x04', b'\x08', b'\x02', b'\x00',
  b'\x00', b'\x00', b'\x26', b'\x93', b'\x09', b'\x29', b'\x00', b'\x00', b'\x00',
  b'\x11', b'\x49', b'\x44', b'\x41', b'\x54', b'\x78', b'\x9C', b'\x63', b'\xFC',
  b'\xCF', b'\x80', b'\x00', b'\x4C', b'\x48', b'\x6C', b'\x3C', b'\x1C', b'\x00',
  b'\x33', b'\xD1', b'\x01', b'\x07', b'\x30', b'\xE7', b'\xE1', b'\x4C', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x49', b'\x45', b'\x4E', b'\x44', b'\xAE', b'\x42',
  b'\x60', b'\x82',
])

///|
let test_4x4_red_bmp : Bytes = Bytes::from_array([
  b'\x42', b'\x4D', b'\x66', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x36', b'\x00', b'\x00', b'\x00', b'\x28', b'\x00', b'\x00', b'\x00',
  b'\x04', b'\x00', b'\x00', b'\x00', b'\x04', b'\x00', b'\x00', b'\x00', b'\x01',
  b'\x00', b'\x18', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x30', b'\x00',
  b'\x00', b'\x00', b'\xC4', b'\x0E', b'\x00', b'\x00', b'\xC4', b'\x0E', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
  b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
  b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
  b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
  b'\x00', b'\x00', b'\xFF',
])

///|
let test_4x4_red_gif : Bytes = Bytes::from_array([
  b'\x47', b'\x49', b'\x46', b'\x38', b'\x37', b'\x61', b'\x04', b'\x00', b'\x04',
  b'\x00', b'\x81', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x2C', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x04', b'\x00', b'\x04', b'\x00', b'\x00', b'\x08',
  b'\x09', b'\x00', b'\x01', b'\x08', b'\x1C', b'\x48', b'\xB0', b'\x20', b'\x80',
  b'\x80', b'\x00', b'\x3B',
])

///|
let test_4x4_red_jpg : Bytes = Bytes::from_array([
  b'\xFF', b'\xD8', b'\xFF', b'\xE0', b'\x00', b'\x10', b'\x4A', b'\x46', b'\x49',
  b'\x46', b'\x00', b'\x01', b'\x01', b'\x00', b'\x00', b'\x01', b'\x00', b'\x01',
  b'\x00', b'\x00', b'\xFF', b'\xDB', b'\x00', b'\x43', b'\x00', b'\x08', b'\x06',
  b'\x06', b'\x07', b'\x06', b'\x05', b'\x08', b'\x07', b'\x07', b'\x07', b'\x09',
  b'\x09', b'\x08', b'\x0A', b'\x0C', b'\x14', b'\x0D', b'\x0C', b'\x0B', b'\x0B',
  b'\x0C', b'\x19', b'\x12', b'\x13', b'\x0F', b'\x14', b'\x1D', b'\x1A', b'\x1F',
  b'\x1E', b'\x1D', b'\x1A', b'\x1C', b'\x1C', b'\x20', b'\x24', b'\x2E', b'\x27',
  b'\x20', b'\x22', b'\x2C', b'\x23', b'\x1C', b'\x1C', b'\x28', b'\x37', b'\x29',
  b'\x2C', b'\x30', b'\x31', b'\x34', b'\x34', b'\x34', b'\x1F', b'\x27', b'\x39',
  b'\x3D', b'\x38', b'\x32', b'\x3C', b'\x2E', b'\x33', b'\x34', b'\x32', b'\xFF',
  b'\xDB', b'\x00', b'\x43', b'\x01', b'\x09', b'\x09', b'\x09', b'\x0C', b'\x0B',
  b'\x0C', b'\x18', b'\x0D', b'\x0D', b'\x18', b'\x32', b'\x21', b'\x1C', b'\x21',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\x32',
  b'\x32', b'\x32', b'\x32', b'\x32', b'\x32', b'\xFF', b'\xC0', b'\x00', b'\x11',
  b'\x08', b'\x00', b'\x04', b'\x00', b'\x04', b'\x03', b'\x01', b'\x22', b'\x00',
  b'\x02', b'\x11', b'\x01', b'\x03', b'\x11', b'\x01', b'\xFF', b'\xC4', b'\x00',
  b'\x1F', b'\x00', b'\x00', b'\x01', b'\x05', b'\x01', b'\x01', b'\x01', b'\x01',
  b'\x01', b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
  b'\x09', b'\x0A', b'\x0B', b'\xFF', b'\xC4', b'\x00', b'\xB5', b'\x10', b'\x00',
  b'\x02', b'\x01', b'\x03', b'\x03', b'\x02', b'\x04', b'\x03', b'\x05', b'\x05',
  b'\x04', b'\x04', b'\x00', b'\x00', b'\x01', b'\x7D', b'\x01', b'\x02', b'\x03',
  b'\x00', b'\x04', b'\x11', b'\x05', b'\x12', b'\x21', b'\x31', b'\x41', b'\x06',
  b'\x13', b'\x51', b'\x61', b'\x07', b'\x22', b'\x71', b'\x14', b'\x32', b'\x81',
  b'\x91', b'\xA1', b'\x08', b'\x23', b'\x42', b'\xB1', b'\xC1', b'\x15', b'\x52',
  b'\xD1', b'\xF0', b'\x24', b'\x33', b'\x62', b'\x72', b'\x82', b'\x09', b'\x0A',
  b'\x16', b'\x17', b'\x18', b'\x19', b'\x1A', b'\x25', b'\x26', b'\x27', b'\x28',
  b'\x29', b'\x2A', b'\x34', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39', b'\x3A',
  b'\x43', b'\x44', b'\x45', b'\x46', b'\x47', b'\x48', b'\x49', b'\x4A', b'\x53',
  b'\x54', b'\x55', b'\x56', b'\x57', b'\x58', b'\x59', b'\x5A', b'\x63', b'\x64',
  b'\x65', b'\x66', b'\x67', b'\x68', b'\x69', b'\x6A', b'\x73', b'\x74', b'\x75',
  b'\x76', b'\x77', b'\x78', b'\x79', b'\x7A', b'\x83', b'\x84', b'\x85', b'\x86',
  b'\x87', b'\x88', b'\x89', b'\x8A', b'\x92', b'\x93', b'\x94', b'\x95', b'\x96',
  b'\x97', b'\x98', b'\x99', b'\x9A', b'\xA2', b'\xA3', b'\xA4', b'\xA5', b'\xA6',
  b'\xA7', b'\xA8', b'\xA9', b'\xAA', b'\xB2', b'\xB3', b'\xB4', b'\xB5', b'\xB6',
  b'\xB7', b'\xB8', b'\xB9', b'\xBA', b'\xC2', b'\xC3', b'\xC4', b'\xC5', b'\xC6',
  b'\xC7', b'\xC8', b'\xC9', b'\xCA', b'\xD2', b'\xD3', b'\xD4', b'\xD5', b'\xD6',
  b'\xD7', b'\xD8', b'\xD9', b'\xDA', b'\xE1', b'\xE2', b'\xE3', b'\xE4', b'\xE5',
  b'\xE6', b'\xE7', b'\xE8', b'\xE9', b'\xEA', b'\xF1', b'\xF2', b'\xF3', b'\xF4',
  b'\xF5', b'\xF6', b'\xF7', b'\xF8', b'\xF9', b'\xFA', b'\xFF', b'\xC4', b'\x00',
  b'\x1F', b'\x01', b'\x00', b'\x03', b'\x01', b'\x01', b'\x01', b'\x01', b'\x01',
  b'\x01', b'\x01', b'\x01', b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
  b'\x09', b'\x0A', b'\x0B', b'\xFF', b'\xC4', b'\x00', b'\xB5', b'\x11', b'\x00',
  b'\x02', b'\x01', b'\x02', b'\x04', b'\x04', b'\x03', b'\x04', b'\x07', b'\x05',
  b'\x04', b'\x04', b'\x00', b'\x01', b'\x02', b'\x77', b'\x00', b'\x01', b'\x02',
  b'\x03', b'\x11', b'\x04', b'\x05', b'\x21', b'\x31', b'\x06', b'\x12', b'\x41',
  b'\x51', b'\x07', b'\x61', b'\x71', b'\x13', b'\x22', b'\x32', b'\x81', b'\x08',
  b'\x14', b'\x42', b'\x91', b'\xA1', b'\xB1', b'\xC1', b'\x09', b'\x23', b'\x33',
  b'\x52', b'\xF0', b'\x15', b'\x62', b'\x72', b'\xD1', b'\x0A', b'\x16', b'\x24',
  b'\x34', b'\xE1', b'\x25', b'\xF1', b'\x17', b'\x18', b'\x19', b'\x1A', b'\x26',
  b'\x27', b'\x28', b'\x29', b'\x2A', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39',
  b'\x3A', b'\x43', b'\x44', b'\x45', b'\x46', b'\x47', b'\x48', b'\x49', b'\x4A',
  b'\x53', b'\x54', b'\x55', b'\x56', b'\x57', b'\x58', b'\x59', b'\x5A', b'\x63',
  b'\x64', b'\x65', b'\x66', b'\x67', b'\x68', b'\x69', b'\x6A', b'\x73', b'\x74',
  b'\x75', b'\x76', b'\x77', b'\x78', b'\x79', b'\x7A', b'\x82', b'\x83', b'\x84',
  b'\x85', b'\x86', b'\x87', b'\x88', b'\x89', b'\x8A', b'\x92', b'\x93', b'\x94',
  b'\x95', b'\x96', b'\x97', b'\x98', b'\x99', b'\x9A', b'\xA2', b'\xA3', b'\xA4',
  b'\xA5', b'\xA6', b'\xA7', b'\xA8', b'\xA9', b'\xAA', b'\xB2', b'\xB3', b'\xB4',
  b'\xB5', b'\xB6', b'\xB7', b'\xB8', b'\xB9', b'\xBA', b'\xC2', b'\xC3', b'\xC4',
  b'\xC5', b'\xC6', b'\xC7', b'\xC8', b'\xC9', b'\xCA', b'\xD2', b'\xD3', b'\xD4',
  b'\xD5', b'\xD6', b'\xD7', b'\xD8', b'\xD9', b'\xDA', b'\xE2', b'\xE3', b'\xE4',
  b'\xE5', b'\xE6', b'\xE7', b'\xE8', b'\xE9', b'\xEA', b'\xF2', b'\xF3', b'\xF4',
  b'\xF5', b'\xF6', b'\xF7', b'\xF8', b'\xF9', b'\xFA', b'\xFF', b'\xDA', b'\x00',
  b'\x0C', b'\x03', b'\x01', b'\x00', b'\x02', b'\x11', b'\x03', b'\x11', b'\x00',
  b'\x3F', b'\x00', b'\xE2', b'\xE8', b'\xA2', b'\x8A', b'\xF9', b'\x93', b'\xF7',
  b'\x13', b'\xFF', b'\xD9',
])

///|
let corrupt_random_bin : Bytes = Bytes::from_array([
  b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07',
])

///|
let corrupt_truncated_png : Bytes = Bytes::from_array([
  b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', b'\x00',
  b'\x00', b'\x00', b'\x0D', b'\x49', b'\x48', b'\x44', b'\x52', b'\x00', b'\x00',
  b'\x00', b'\x04', b'\x00', b'\x00', b'\x00', b'\x04', b'\x08', b'\x02', b'\x00',
  b'\x00', b'\x00', b'\x26', b'\x93', b'\x09', b'\x29', b'\x00', b'\x00', b'\x00',
  b'\x11',
])

///|
fn make_rgb_image(
  width : Int,
  height : Int,
  pixels : Array[(Int, Int, Int)],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.0.to_byte())
    data.push(p.1.to_byte())
    data.push(p.2.to_byte())
  }
  @types.Image::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
fn make_gray_image(
  width : Int,
  height : Int,
  values : Array[Int],
) -> @types.Image {
  @types.Image::{
    width,
    height,
    channels: 1,
    data: Bytes::from_array(values.map(fn(v) { v.to_byte() })),
  }
}

///|
fn make_gradient_image(width : Int, height : Int) -> @types.Image {
  let data : Array[Byte] = []
  for y in 0..<height {
    for x in 0..<width {
      let v = ((x + y) * 255 / (width + height - 2)).clamp(min=0, max=255)
      data.push(v.to_byte())
    }
  }
  @types.Image::{ width, height, channels: 1, data: Bytes::from_array(data) }
}

///|
fn has_non_zero_pixel(img : @types.Image) -> Bool {
  let len = img.data.length()
  for i in 0..<len {
    if img.data[i].to_int() > 0 {
      return true
    }
  }
  false
}

///|
fn is_binary_image(img : @types.Image) -> Bool {
  let len = img.data.length()
  for i in 0..<len {
    let v = img.data[i].to_int()
    if v != 0 && v != 255 {
      return false
    }
  }
  true
}

///|
fn images_differ(a : @types.Image, b : @types.Image) -> Bool {
  let len = a.data.length()
  for i in 0..<len {
    if a.data[i] != b.data[i] {
      return true
    }
  }
  false
}
