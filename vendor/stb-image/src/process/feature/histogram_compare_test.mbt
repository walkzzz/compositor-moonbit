///|
test "compare_hist: Correlation identical histograms" {
  let h1 = [10, 20, 30, 40, 50, 60, 70, 80]
  let h2 = [10, 20, 30, 40, 50, 60, 70, 80]
  let result = compare_hist(h1, h2, HistCompareMethod::Correlation)
  // Identical histograms → correlation = 1.0
  assert_true((result - 1.0F).abs() < 0.001F)
}

///|
test "compare_hist: Correlation different histograms" {
  let h1 = [10, 20, 30, 40]
  let h2 = [40, 30, 20, 10]
  let result = compare_hist(h1, h2, HistCompareMethod::Correlation)
  // Perfectly anti-correlated → correlation = -1.0
  assert_true((result - -1.0F).abs() < 0.001F)
}

///|
test "compare_hist: ChiSquare identical histograms" {
  let h1 = [10, 20, 30, 40]
  let h2 = [10, 20, 30, 40]
  let result = compare_hist(h1, h2, HistCompareMethod::ChiSquare)
  // Identical → chi-square = 0
  assert_true(result < 0.001F)
}

///|
test "compare_hist: ChiSquare different histograms" {
  let h1 = [10, 0, 0, 10]
  let h2 = [0, 10, 10, 0]
  let result = compare_hist(h1, h2, HistCompareMethod::ChiSquare)
  // Completely different → chi-square > 0
  assert_true(result > 0.0F)
}

///|
test "compare_hist: Bhattacharyya identical histograms" {
  let h1 = [10, 20, 30, 40]
  let h2 = [10, 20, 30, 40]
  let result = compare_hist(h1, h2, HistCompareMethod::Bhattacharyya)
  // Identical → BC coefficient = 1.0
  assert_true((result - 1.0F).abs() < 0.001F)
}

///|
test "compare_hist: Bhattacharyya disjoint histograms" {
  let h1 = [10, 0, 0, 0]
  let h2 = [0, 0, 0, 10]
  let result = compare_hist(h1, h2, HistCompareMethod::Bhattacharyya)
  // Disjoint → BC coefficient = 0.0
  assert_true(result < 0.001F)
}

///|
test "histogram_matching: matching image to itself preserves values" {
  let data : Array[Byte] = []
  for i in 0..<16 {
    data.push((i * 16).to_byte())
  }
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = histogram_matching(img, img)
  // Matching to itself should approximately preserve values
  let mut total_diff = 0
  for i in 0..<16 {
    total_diff += (result.data[i].to_int() - img.data[i].to_int()).abs()
  }
  // Allow small differences due to CDF discretization
  assert_true(total_diff < 20)
}

///|
test "histogram_matching: produces same dimensions" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x00\x40\x80\xC0\x00\x40\x80\xC0\x00\x40\x80\xC0\x00\x40\x80\xC0",
  }
  let reference = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: b"\xFF\xAA\x55\x00",
  }
  let result = histogram_matching(img, reference)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
}
