///|
/// 解码结果值对象，承载图像几何元信息与像素数据（8-bit 无符号像素）
pub(all) struct Image {
  width : Int
  height : Int
  channels : Int
  data : Bytes
} derive(Eq, @debug.Debug)

///|
/// 16-bit 解码结果值对象，像素数据为 16-bit 无符号整数（little-endian，每像素 2 字节）
pub(all) struct Image16 {
  width : Int
  height : Int
  channels : Int
  data : Bytes
} derive(Eq, @debug.Debug)

///|
/// HDR float 解码结果值对象，像素数据为 32-bit IEEE float（little-endian，每像素 4 字节）
pub(all) struct ImageF {
  width : Int
  height : Int
  channels : Int
  data : Bytes
} derive(Eq, @debug.Debug)

///|
/// 图像信息查询结果，仅含几何元信息，不加载像素数据
pub(all) struct ImageInfo {
  width : Int
  height : Int
  channels : Int
} derive(Eq, @debug.Debug)

///|
/// 动画 GIF 解码结果，包含多帧图像和每帧延迟（毫秒）
pub(all) struct GifAnimation {
  frames : Array[Image]
  delays : Array[Int]
} derive(Eq, @debug.Debug)

///|
/// 加载失败领域错误
pub(all) suberror LoadError {
  FileIO(String)
  UnsupportedFormat(String)
  DecodeFailed(String)
  EncodeFailed(String)
}

///|
/// 图像格式枚举
pub(all) enum ImageFormat {
  Png
  Jpeg
  Bmp
  Gif
  Tga
  Psd
  Hdr
  Pnm
  Qoi
  Webp
  Tiff
  Ico
  Cur
  Icns
  Apng
  Unknown
} derive(Eq, @debug.Debug)

///|
/// resize 滤波器类型
pub(all) enum ResizeFilter {
  Default
  Box
  Triangle
  CubicBSPline
  CatmullROM
  Mitchell
  PointSample
} derive(Eq, @debug.Debug)

///|
/// resize 边缘处理模式
pub(all) enum ResizeEdge {
  Clamp
  Reflect
  Wrap
  Zero
} derive(Eq, @debug.Debug)

///|
/// APNG 动画解码结果
pub(all) struct PngAnimation {
  frames : Array[Image]
  delays : Array[Int] // 毫秒
} derive(Eq, @debug.Debug)

///|
/// 图像维度上限（单边最大像素数）。
/// 防止恶意图像声明超大尺寸导致 OOM 或整数溢出。
/// 65535 覆盖常见图像格式最大尺寸（PNG/TIFF 32-bit、JPEG 65500、BMP 32-bit）。
pub const MAX_IMAGE_DIMENSION : Int = 65535

///|
/// 校验图像维度是否在安全范围内。
/// 检查 width/height 为正数且不超过 MAX_IMAGE_DIMENSION，
/// 且 width * height * channels 不超过 Int 最大值（防溢出）。
/// 校验失败时 raise LoadError::DecodeFailed。
pub fn check_dims(
  width : Int,
  height : Int,
  channels : Int,
) -> Unit raise LoadError {
  if width <= 0 || height <= 0 || channels <= 0 {
    raise LoadError::DecodeFailed(
      "图像尺寸无效: width=\{width}, height=\{height}, channels=\{channels}",
    )
  }
  if width > MAX_IMAGE_DIMENSION || height > MAX_IMAGE_DIMENSION {
    raise LoadError::DecodeFailed(
      "图像尺寸超过上限 \{MAX_IMAGE_DIMENSION}: width=\{width}, height=\{height}",
    )
  }
  // 检查 width * height * channels 是否溢出
  // Int 在 wasm/native 为 32 位有符号，最大值 2147483647
  // 先算 width * height，再乘 channels
  let max_int = 2147483647
  if width > max_int / height {
    raise LoadError::DecodeFailed(
      "图像像素总数溢出: \{width} * \{height}",
    )
  }
  let pixel_count = width * height
  if pixel_count > max_int / channels {
    raise LoadError::DecodeFailed(
      "图像数据大小溢出: \{pixel_count} * \{channels}",
    )
  }
}

///|
/// 安全乘法：返回 a * b，溢出时返回 None。
/// 用于在分配大数组前检查是否会溢出。
pub fn safe_mul(a : Int, b : Int) -> Int? {
  if a <= 0 || b <= 0 {
    return Some(0)
  }
  let max_int = 2147483647
  if a > max_int / b {
    None
  } else {
    Some(a * b)
  }
}

///|
/// 安全三参数乘法：返回 a * b * c，溢出时返回 None。
/// 常用于计算 w * h * channels 的数组大小。
pub fn safe_mul3(a : Int, b : Int, c : Int) -> Int? {
  match safe_mul(a, b) {
    Some(ab) =>
      match safe_mul(ab, c) {
        Some(result) => Some(result)
        None => None
      }
    None => None
  }
}
