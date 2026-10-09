// 纯 MoonBit GIF 多帧动画解码（全目标可用：native/wasm/js）
// 支持 GIF89a 多帧动画：Graphics Control Extension + 多 Image Descriptor
// 仅依赖 @types，不依赖 @core/FFI

///|
/// 读取 GIF 颜色表
fn gif_read_color_table(
  data : Bytes,
  pos : Int,
  size : Int,
  len : Int,
) -> (Array[(Int, Int, Int)], Int) raise @types.LoadError {
  if pos + size * 3 > len {
    raise @types.LoadError::DecodeFailed(
      "GIF 数据过短：无法读取 Color Table",
    )
  }
  let table : Array[(Int, Int, Int)] = []
  let mut p = pos
  for _ in 0..<size {
    let r = data[p].to_int()
    let g = data[p + 1].to_int()
    let b = data[p + 2].to_int()
    table.push((r, g, b))
    p += 3
  }
  (table, p)
}

///|
/// 读取 GIF 子块数据（收集模式）
fn gif_read_sub_blocks(
  data : Bytes,
  pos : Int,
  len : Int,
) -> (Array[Byte], Int) raise @types.LoadError {
  let result : Array[Byte] = []
  let mut p = pos
  while p < len {
    let sub_len = data[p].to_int()
    p += 1
    if sub_len == 0 {
      break
    }
    if p + sub_len > len {
      raise @types.LoadError::DecodeFailed("GIF 子块长度越界")
    }
    for i in 0..<sub_len {
      result.push(data[p + i])
    }
    p += sub_len
  }
  (result, p)
}

///|
/// 跳过 GIF 子块（不收集数据）
fn gif_skip_sub_blocks(
  data : Bytes,
  pos : Int,
  len : Int,
) -> Int raise @types.LoadError {
  let mut p = pos
  while p < len {
    let sub_len = data[p].to_int()
    p += 1
    if sub_len == 0 {
      break
    }
    if p + sub_len > len {
      raise @types.LoadError::DecodeFailed("GIF 子块长度越界")
    }
    p += sub_len
  }
  p
}

///|
/// 处理 GIF disposal 方法
fn gif_apply_disposal(
  disposal : Int,
  canvas : Array[Byte],
  prev_canvas : Array[Byte],
  left : Int,
  top : Int,
  img_width : Int,
  img_height : Int,
  screen_width : Int,
  screen_height : Int,
  bg_r : Int,
  bg_g : Int,
  bg_b : Int,
) -> Unit {
  match disposal {
    2 =>
      // restore to background
      for y in 0..<img_height {
        for x in 0..<img_width {
          let cx = left + x
          let cy = top + y
          if cx >= screen_width || cy >= screen_height {
            continue
          }
          let canvas_off = (cy * screen_width + cx) * 3
          canvas[canvas_off] = bg_r.to_byte()
          canvas[canvas_off + 1] = bg_g.to_byte()
          canvas[canvas_off + 2] = bg_b.to_byte()
        }
      }
    3 =>
      // restore to previous
      for i in 0..<(screen_width * screen_height * 3) {
        canvas[i] = prev_canvas[i]
      }
    _ => ()
  }
}

///|
/// 将 GIF 帧像素写入 canvas
fn gif_write_frame_pixels(
  indices : Array[Int],
  color_table : Array[(Int, Int, Int)],
  left : Int,
  top : Int,
  img_width : Int,
  img_height : Int,
  screen_width : Int,
  screen_height : Int,
  gce_transparent : Int,
  canvas : Array[Byte],
) -> Unit raise @types.LoadError {
  for y in 0..<img_height {
    for x in 0..<img_width {
      let idx = indices[y * img_width + x]
      let cx = left + x
      let cy = top + y
      if cx >= screen_width || cy >= screen_height {
        continue
      }
      if gce_transparent >= 0 && idx == gce_transparent {
        continue
      }
      if idx >= color_table.length() {
        raise @types.LoadError::DecodeFailed("GIF 颜色表索引越界")
      }
      let (r, g, b) = color_table[idx]
      let canvas_off = (cy * screen_width + cx) * 3
      canvas[canvas_off] = r.to_byte()
      canvas[canvas_off + 1] = g.to_byte()
      canvas[canvas_off + 2] = b.to_byte()
    }
  }
}

///|
/// 解码 GIF 动画为 GifAnimation（纯 MoonBit，全目标可用）。
/// 支持多帧动画、延迟时间、基本 disposal 方法。
/// 不支持 interlace。
pub fn decode_gif_animation_pure(
  data : Bytes,
) -> @types.GifAnimation raise @types.LoadError {
  let len = data.length()
  if len < 13 {
    raise @types.LoadError::DecodeFailed(
      "GIF 数据过短：无法读取完整 header",
    )
  }
  if data[0].to_int() != 0x47 ||
    data[1].to_int() != 0x49 ||
    data[2].to_int() != 0x46 ||
    data[3].to_int() != 0x38 ||
    (data[4].to_int() != 0x39 && data[4].to_int() != 0x37) ||
    data[5].to_int() != 0x61 {
    raise @types.LoadError::DecodeFailed(
      "GIF signature 错误，非 \"GIF87a\"/\"GIF89a\"",
    )
  }
  let screen_width = read_u16_le(data, 6)
  let screen_height = read_u16_le(data, 8)
  @types.check_dims(screen_width, screen_height, 3)
  let packed = data[10].to_int()
  let has_gct = (packed & 0x80) != 0
  let gct_size = 1 << ((packed & 0x07) + 1)
  let bg_idx = data[11].to_int()
  let mut pos = 13
  let gct : Array[(Int, Int, Int)] = if has_gct {
    let (table, new_pos) = gif_read_color_table(data, pos, gct_size, len)
    pos = new_pos
    table
  } else {
    []
  }
  let (bg_r, bg_g, bg_b) = if bg_idx < gct.length() {
    gct[bg_idx]
  } else {
    (0, 0, 0)
  }
  let frames : Array[@types.Image] = []
  let delays : Array[Int] = []
  let canvas : Array[Byte] = Array::make(
    screen_width * screen_height * 3,
    bg_r.to_byte(),
  )
  for i in 0..<(screen_width * screen_height) {
    canvas[i * 3] = bg_r.to_byte()
    canvas[i * 3 + 1] = bg_g.to_byte()
    canvas[i * 3 + 2] = bg_b.to_byte()
  }
  let prev_canvas : Array[Byte] = Array::make(
    screen_width * screen_height * 3,
    b'\x00',
  )
  let mut gce_delay = 0
  let mut gce_transparent = -1
  let mut gce_disposal = 0
  while pos < len {
    let block_type = data[pos].to_int()
    pos += 1
    match block_type {
      0x2C => {
        // Image Descriptor
        if pos + 9 > len {
          raise @types.LoadError::DecodeFailed(
            "GIF 数据过短：无法读取 Image Descriptor",
          )
        }
        let left = read_u16_le(data, pos)
        let top = read_u16_le(data, pos + 2)
        let img_width = read_u16_le(data, pos + 4)
        let img_height = read_u16_le(data, pos + 6)
        let img_packed = data[pos + 8].to_int()
        pos += 9
        let has_lct = (img_packed & 0x80) != 0
        let is_interlaced = (img_packed & 0x40) != 0
        let lct_size_val = 1 << ((img_packed & 0x07) + 1)
        if is_interlaced {
          raise @types.LoadError::DecodeFailed("GIF interlace 不支持")
        }
        let lct : Array[(Int, Int, Int)] = if has_lct {
          let (table, new_pos) = gif_read_color_table(
            data, pos, lct_size_val, len,
          )
          pos = new_pos
          table
        } else {
          []
        }
        if pos >= len {
          raise @types.LoadError::DecodeFailed(
            "GIF 数据过短：无法读取 LZW min code size",
          )
        }
        let lzw_min_code_size = data[pos].to_int()
        pos += 1
        if lzw_min_code_size < 2 || lzw_min_code_size > 8 {
          raise @types.LoadError::DecodeFailed(
            "GIF LZW minimum code size 无效",
          )
        }
        let (lzw_data, new_pos) = gif_read_sub_blocks(data, pos, len)
        pos = new_pos
        let indices = lzw_decode(lzw_data, lzw_min_code_size)
        let color_table = if lct.length() > 0 { lct } else { gct }
        if color_table.length() == 0 {
          raise @types.LoadError::DecodeFailed("GIF 无颜色表可用")
        }
        for i in 0..<(screen_width * screen_height * 3) {
          prev_canvas[i] = canvas[i]
        }
        gif_write_frame_pixels(
          indices, color_table, left, top, img_width, img_height, screen_width, screen_height,
          gce_transparent, canvas,
        )
        let frame_data : Array[Byte] = Array::make(
          screen_width * screen_height * 3,
          b'\x00',
        )
        for i in 0..<(screen_width * screen_height * 3) {
          frame_data[i] = canvas[i]
        }
        frames.push(@types.Image::{
          width: screen_width,
          height: screen_height,
          channels: 3,
          data: Bytes::from_array(frame_data),
        })
        delays.push(gce_delay)
        gif_apply_disposal(
          gce_disposal, canvas, prev_canvas, left, top, img_width, img_height, screen_width,
          screen_height, bg_r, bg_g, bg_b,
        )
        gce_delay = 0
        gce_transparent = -1
        gce_disposal = 0
      }
      0x21 => {
        // Extension
        if pos >= len {
          raise @types.LoadError::DecodeFailed(
            "GIF 数据过短：无法读取 Extension label",
          )
        }
        let label = data[pos].to_int()
        pos += 1
        if label == 0xF9 && pos + 6 <= len {
          // Graphics Control Extension
          let _block_size = data[pos].to_int()
          let gce_packed = data[pos + 1].to_int()
          gce_delay = read_u16_le(data, pos + 2) * 10
          gce_transparent = if (gce_packed & 0x01) != 0 {
            data[pos + 4].to_int()
          } else {
            -1
          }
          gce_disposal = (gce_packed >> 2) & 0x07
          pos += 6
        } else if label == 0x01 {
          // Plain Text Extension
          if pos + 8 > len {
            raise @types.LoadError::DecodeFailed(
              "GIF 数据过短：无法读取 Plain Text Extension header",
            )
          }
          pos += 8
          pos = gif_skip_sub_blocks(data, pos, len)
        } else {
          pos = gif_skip_sub_blocks(data, pos, len)
        }
      }
      0x3B => break
      _ => raise @types.LoadError::DecodeFailed("GIF 未知 block type")
    }
  }
  if frames.length() == 0 {
    raise @types.LoadError::DecodeFailed("GIF 无 Image Separator")
  }
  @types.GifAnimation::{ frames, delays }
}
