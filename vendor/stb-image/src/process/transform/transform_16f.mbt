// 图像变换 16-bit/float 变体：rotate / flip
// 支持 Image16 / ImageF 两种类型

///|
pub fn rotate_90_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.height - 1 - y
      let ny = x
      let src = (y * img.width + x) * bpp
      let dst = (ny * new_w + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn rotate_90_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.height - 1 - y
      let ny = x
      let src = (y * img.width + x) * bpp
      let dst = (ny * new_w + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn rotate_180_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.width - 1 - x
      let ny = img.height - 1 - y
      let src = (y * img.width + x) * bpp
      let dst = (ny * img.width + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn rotate_180_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.width - 1 - x
      let ny = img.height - 1 - y
      let src = (y * img.width + x) * bpp
      let dst = (ny * img.width + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn rotate_270_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = y
      let ny = img.width - 1 - x
      let src = (y * img.width + x) * bpp
      let dst = (ny * new_w + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn rotate_270_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = y
      let ny = img.width - 1 - x
      let src = (y * img.width + x) * bpp
      let dst = (ny * new_w + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn flip_horizontal_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.width - 1 - x
      let src = (y * img.width + x) * bpp
      let dst = (y * img.width + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
pub fn flip_horizontal_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let nx = img.width - 1 - x
      let src = (y * img.width + x) * bpp
      let dst = (y * img.width + nx) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 垂直翻转。上下镜像。
pub fn flip_vertical_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    let ny = img.height - 1 - y
    for x in 0..<img.width {
      let src = (y * img.width + x) * bpp
      let dst = (ny * img.width + x) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 垂直翻转。上下镜像。
pub fn flip_vertical_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(img.width * img.height * bpp, b'\x00')
  for y in 0..<img.height {
    let ny = img.height - 1 - y
    for x in 0..<img.width {
      let src = (y * img.width + x) * bpp
      let dst = (ny * img.width + x) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 转置。交换宽高，(x,y) -> (y,x)。
pub fn transpose_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let src = (y * img.width + x) * bpp
      let dst = (x * new_w + y) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 转置。交换宽高，(x,y) -> (y,x)。
pub fn transpose_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(new_w * new_h * bpp, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let src = (y * img.width + x) * bpp
      let dst = (x * new_w + y) * bpp
      for i in 0..<bpp {
        out[dst + i] = img.data[src + i]
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
