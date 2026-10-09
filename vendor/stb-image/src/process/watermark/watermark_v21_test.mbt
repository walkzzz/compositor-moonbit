// v21.0.0 图像加密与水印增强测试 - watermark 模块

///|
fn make_wm_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
test "watermark_default_config: 返回有效配置" {
  let config = watermark_default_config()
  assert_true(config.strength > 0.0)
}

///|
test "embed_watermark_lsb: 基本嵌入" {
  let cover = make_wm_img(8, 8, b'\x80')
  let watermark = make_wm_img(8, 8, b'\xFF')
  let stego = embed_watermark_lsb(cover, watermark)
  assert_eq(stego.width, 8)
  assert_eq(stego.height, 8)
  assert_eq(stego.data.length(), 64)
}

///|
test "extract_watermark_lsb: 基本提取" {
  let cover = make_wm_img(8, 8, b'\x80')
  let watermark = make_wm_img(8, 8, b'\xFF')
  let stego = embed_watermark_lsb(cover, watermark)
  let extracted = extract_watermark_lsb(stego)
  assert_eq(extracted.width, 8)
  assert_eq(extracted.height, 8)
}

///|
test "embed_text_watermark: 基本嵌入" {
  let cover = make_wm_img(16, 16, b'\x80')
  let stego = embed_text_watermark(cover, "AB")
  assert_eq(stego.width, 16)
  assert_eq(stego.height, 16)
  assert_eq(stego.data.length(), 256)
}

///|
test "extract_text_watermark: 基本提取" {
  let cover = make_wm_img(16, 16, b'\x80')
  let stego = embed_text_watermark(cover, "AB")
  let result = extract_text_watermark(stego, 2)
  assert_true(result.length() > 0)
}

///|
test "watermark_psnr: 相同图像" {
  let img = make_wm_img(4, 4, b'\x80')
  let psnr = watermark_psnr(img, img)
  assert_true(psnr > 90.0)
}

///|
test "watermark_psnr: 不同图像" {
  let img1 = make_wm_img(4, 4, b'\x00')
  let img2 = make_wm_img(4, 4, b'\xFF')
  let psnr = watermark_psnr(img1, img2)
  assert_true(psnr >= 0.0)
}

///|
test "watermark_robustness_test: 基本测试" {
  let cover = make_wm_img(8, 8, b'\x80')
  let watermark = make_wm_img(8, 8, b'\xFF')
  let stego = embed_watermark_lsb(cover, watermark)
  let robustness = watermark_robustness_test(stego, watermark)
  assert_true(robustness >= 0.0 && robustness <= 1.0)
}

///|
test "batch_embed_watermark: 基本批量" {
  let cover1 = make_wm_img(8, 8, b'\x80')
  let cover2 = make_wm_img(8, 8, b'\x40')
  let watermark = make_wm_img(8, 8, b'\xFF')
  let results = batch_embed_watermark([cover1, cover2], watermark)
  assert_eq(results.length(), 2)
}
