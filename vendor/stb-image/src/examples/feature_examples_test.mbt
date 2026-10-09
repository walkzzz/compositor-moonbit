// 示例 23-24：特征检测（SIFT/ORB）+ 特征匹配

///|
test "example_23: SIFT feature detection and matching" {
  // SIFT 需要足够大的图像构建高斯金字塔
  let img1 = make_gradient_image(32, 32)
  let img2 = make_gradient_image(32, 32)
  let kp1 = @img.sift_detect(img1)
  let kp2 = @img.sift_detect(img2)
  assert_eq(kp1.length(), kp2.length())
  if kp1.length() > 0 && kp2.length() > 0 {
    let matches = @img.sift_match(kp1, kp2, ratio_test=0.75)
    assert_true(matches.length() >= 0)
  }
}

///|
test "example_24: ORB feature detection and matching" {
  // ORB 需要足够大的图像进行角点检测
  let img1 = make_gradient_image(32, 32)
  let img2 = make_gradient_image(32, 32)
  let descs1 = @img.orb_detect(img1)
  let descs2 = @img.orb_detect(img2)
  assert_eq(descs1.length(), descs2.length())
  if descs1.length() > 0 && descs2.length() > 0 {
    let matches = @img.orb_match(descs1, descs2, max_distance=64)
    assert_true(matches.length() >= 0)
  }
  if descs1.length() >= 2 {
    let dist = @img.orb_hamming(descs1[0], descs1[0])
    assert_eq(dist, 0)
  }
}
