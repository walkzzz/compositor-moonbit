// lib 包：统一分派入口（格式分派层）
// 职责：通过 magic bytes 检测图像格式，并委托 pure/codec 进行解码、pure/color 进行通道转换
// 注意：TGA 无固定 magic bytes，需显式调用 @codec.decode_tga_pure
//       HDR 返回 ImageF（浮点图像），需显式调用 @codec.decode_hdr_pure

///|
pub type ImageFormat = @types.ImageFormat

///|
/// 通过 magic bytes 检测图像格式
/// - BMP "BM"、QOI "qoif"、PNM "P5"/"P6"、PSD "8BPS"、GIF "GIF87a"/"GIF89a"
/// - PNG 8字节签名、JPEG SOI 0xFF 0xD8
/// - WebP: RIFF....WEBP
/// - ICNS: 前4字节 "icns"
/// - TIFF: 字节序标记 + magic 0x002A
/// - ICO/CUR: 前4字节 00 00 01 00
/// - TGA 无固定 magic bytes，检测为 Unknown，需显式调用 @codec.decode_tga_pure
pub fn detect_format(data : Bytes) -> @types.ImageFormat {
  let len = data.length()
  if len < 2 {
    return @types.ImageFormat::Unknown
  }
  // PNG: 8字节签名
  if len >= 8 &&
    data[0].to_int() == 0x89 &&
    data[1].to_int() == 0x50 &&
    data[2].to_int() == 0x4E &&
    data[3].to_int() == 0x47 &&
    data[4].to_int() == 0x0D &&
    data[5].to_int() == 0x0A &&
    data[6].to_int() == 0x1A &&
    data[7].to_int() == 0x0A {
    return @types.ImageFormat::Png
  }
  // JPEG: SOI marker
  if data[0].to_int() == 0xFF && data[1].to_int() == 0xD8 {
    return @types.ImageFormat::Jpeg
  }
  // BMP: "BM"
  if data[0].to_int() == 0x42 && data[1].to_int() == 0x4D {
    return @types.ImageFormat::Bmp
  }
  // QOI: "qoif"
  if len >= 4 &&
    data[0].to_int() == 0x71 &&
    data[1].to_int() == 0x6F &&
    data[2].to_int() == 0x69 &&
    data[3].to_int() == 0x66 {
    return @types.ImageFormat::Qoi
  }
  // PNM: "P5"/"P6"
  if data[0].to_int() == 0x50 &&
    data[1].to_int() >= 0x35 &&
    data[1].to_int() <= 0x36 {
    return @types.ImageFormat::Pnm
  }
  // PSD: "8BPS"
  if len >= 4 &&
    data[0].to_int() == 0x38 &&
    data[1].to_int() == 0x42 &&
    data[2].to_int() == 0x50 &&
    data[3].to_int() == 0x53 {
    return @types.ImageFormat::Psd
  }
  // GIF: "GIF87a" or "GIF89a"
  if len >= 6 &&
    data[0].to_int() == 0x47 &&
    data[1].to_int() == 0x49 &&
    data[2].to_int() == 0x46 {
    return @types.ImageFormat::Gif
  }
  // HDR: #?RADIANCE
  if len >= 10 &&
    data[0].to_int() == 0x23 &&
    data[1].to_int() == 0x3F &&
    data[2].to_int() == 0x52 {
    return @types.ImageFormat::Hdr
  }
  // WebP: RIFF....WEBP
  if len >= 12 &&
    data[0].to_int() == 0x52 &&
    data[1].to_int() == 0x49 &&
    data[2].to_int() == 0x46 &&
    data[3].to_int() == 0x46 &&
    data[8].to_int() == 0x57 &&
    data[9].to_int() == 0x45 &&
    data[10].to_int() == 0x42 &&
    data[11].to_int() == 0x50 {
    return @types.ImageFormat::Webp
  }
  // ICNS: 前4字节 "icns"
  if len >= 4 &&
    data[0].to_int() == 0x69 &&
    data[1].to_int() == 0x63 &&
    data[2].to_int() == 0x6E &&
    data[3].to_int() == 0x73 {
    return @types.ImageFormat::Icns
  }
  // TIFF: 字节序标记 (II=0x4949 LE, MM=0x4D4D BE) + magic 42 (offset 2-3)
  if (data[0].to_int() == 0x49 && data[1].to_int() == 0x49) ||
    (data[0].to_int() == 0x4D && data[1].to_int() == 0x4D) {
    if len >= 4 &&
      (
        (data[2].to_int() == 0x2A && data[3].to_int() == 0x00) ||
        (data[2].to_int() == 0x00 && data[3].to_int() == 0x2A)
      ) {
      return @types.ImageFormat::Tiff
    }
  }
  // ICO/CUR: 00 00 XX 00 + 图像数量 (≥1) + 目录条目
  // XX = 01 (ICO) 或 02 (CUR)，总长度至少 22 字节（6 头 + 16 目录条目）
  if len >= 22 &&
    data[0].to_int() == 0x00 &&
    data[1].to_int() == 0x00 &&
    (data[2].to_int() == 0x01 || data[2].to_int() == 0x02) &&
    data[3].to_int() == 0x00 &&
    data[4].to_int() != 0 { // 图像数量必须非零
    // 读取第一个目录条目的 width/height
    let width = data[6].to_int()
    let height = data[7].to_int()
    // CUR: width=0 且 height=0 表示热点坐标占位
    if data[2].to_int() == 0x02 && width == 0 && height == 0 {
      return @types.ImageFormat::Cur
    }
    return @types.ImageFormat::Ico
  }
  @types.ImageFormat::Unknown
}

///|
/// 自动格式分派解码（pure 侧统一入口）
/// 根据 magic bytes 检测格式并委托对应 pure 解码器
/// - 不支持 TGA 自动分派（无固定 magic bytes），需显式调用 @codec.decode_tga_pure
/// - HDR 返回 ImageF，需显式调用 @codec.decode_hdr_pure
/// - APNG 与 PNG 共享签名，需显式调用 decode_apng_pure
/// - 未识别格式 raise LoadError::DecodeFailed
pub fn load_from_bytes_auto(
  data : Bytes,
  req_channels? : Int? = None,
) -> @types.Image raise @types.LoadError {
  let img = match detect_format(data) {
    @types.ImageFormat::Png => @codec.decode_png_pure(data, req_channels~)
    @types.ImageFormat::Jpeg => @codec.decode_jpeg_pure(data)
    @types.ImageFormat::Bmp => @codec.decode_bmp_pure(data)
    @types.ImageFormat::Qoi => @codec.decode_qoi_pure(data)
    @types.ImageFormat::Pnm => @codec.decode_pnm_pure(data)
    @types.ImageFormat::Psd => @codec.decode_psd_pure(data)
    @types.ImageFormat::Gif => @codec.decode_gif_pure(data)
    @types.ImageFormat::Webp => @codec.decode_webp_pure(data)
    @types.ImageFormat::Hdr =>
      raise @types.LoadError::DecodeFailed(
        "HDR 格式需要显式调用 decode_hdr_pure",
      )
    @types.ImageFormat::Tga => @codec.decode_tga_pure(data)
    @types.ImageFormat::Tiff => @codec.decode_tiff_pure(data)
    @types.ImageFormat::Ico => @codec.decode_ico_pure(data)
    @types.ImageFormat::Cur => @codec.decode_cur_pure(data)
    @types.ImageFormat::Icns => @codec.decode_icns_pure(data)
    @types.ImageFormat::Apng =>
      raise @types.LoadError::DecodeFailed(
        "APNG 格式需要显式调用 decode_apng_pure",
      )
    @types.ImageFormat::Unknown =>
      raise @types.LoadError::DecodeFailed(
        "不支持或无法识别的格式（TGA 无 magic bytes，需显式调用 decode_tga_pure）",
      )
  }
  match req_channels {
    Some(n) => @color.convert_channels_pure(img, n)
    None => img
  }
}

///|
/// 16-bit 自动格式分派解码（纯 MoonBit，全目标可用）
/// 根据格式委托对应 16-bit 解码器，输出 Image16（little-endian uint16）
/// - PNG: 支持 8-bit 上采样和原生 16-bit
/// - PNM: 支持 8-bit 上采样和原生 16-bit
/// - 其他格式不支持 16-bit
/// 注意：req_channels 仅对 PNG 生效，PNM 分支不传递 req_channels
pub fn load_16_from_bytes_auto(
  data : Bytes,
  req_channels? : Int? = None,
) -> @types.Image16 raise @types.LoadError {
  match detect_format(data) {
    @types.ImageFormat::Png => @codec.decode_png_16_pure(data, req_channels~)
    @types.ImageFormat::Pnm => @codec.decode_pnm_16_pure(data)
    _ =>
      raise @types.LoadError::DecodeFailed(
        "16-bit 解码不支持此格式，仅支持 PNG 和 PNM",
      )
  }
}

///|
/// QOI 编码委托
pub fn encode_qoi(img : @types.Image) -> Bytes raise @types.LoadError {
  @codec.encode_qoi_pure(img)
}

///|
/// PNM 编码委托（channels<=1 → PGM else → PPM）
pub fn encode_pnm_auto(img : @types.Image) -> Bytes {
  @codec.encode_pnm_pure(img)
}

///|
/// PPM 编码委托
pub fn encode_ppm_auto(img : @types.Image) -> Bytes {
  @codec.encode_ppm_pure(img)
}

///|
/// PGM 编码委托
pub fn encode_pgm_auto(img : @types.Image) -> Bytes {
  @codec.encode_pgm_pure(img)
}

///|
/// GIF 编码委托
pub fn encode_gif(img : @types.Image) -> Bytes raise @types.LoadError {
  @codec.encode_gif_pure(img)
}

///|
/// PNG 编码委托
pub fn encode_png(img : @types.Image) -> Bytes {
  @codec.encode_png_pure(img)
}

///|
/// JPEG 编码委托
pub fn encode_jpeg(img : @types.Image) -> Bytes raise @types.LoadError {
  @codec.encode_jpeg_pure(img)
}

///|
/// HDR 编码委托
pub fn encode_hdr(img : @types.ImageF) -> Bytes raise @types.LoadError {
  @codec.encode_hdr_pure(img)
}

///|
/// BMP 编码委托
pub fn encode_bmp(img : @types.Image) -> Bytes {
  @codec.encode_bmp_pure(img)
}

///|
/// TGA 编码委托
pub fn encode_tga(img : @types.Image) -> Bytes {
  @codec.encode_tga_pure(img)
}
