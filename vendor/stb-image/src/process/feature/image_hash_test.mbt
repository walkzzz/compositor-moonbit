///|
fn make_solid_gray_8x8(v : Int) -> @types.Image {
  let data : Array[Byte] = Array::make(64, v.to_byte())
  @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn make_gradient_8x8() -> @types.Image {
  let data : Array[Byte] = Array::make(64, b'\x00')
  for y in 0..<8 {
    for x in 0..<8 {
      data[y * 8 + x] = (x * 32).to_byte()
    }
  }
  @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
test "ahash: returns 64-element hash" {
  let img = make_gradient_8x8()
  let hash = ahash(img)
  assert_eq(hash.length(), 64)
}

///|
test "ahash: solid image has uniform hash" {
  let img = make_solid_gray_8x8(128)
  let hash = ahash(img)
  // All pixels equal mean, so all bits should be 0
  for i in 0..<64 {
    assert_eq(hash[i], 0)
  }
}

///|
test "dhash: returns 64-element hash" {
  let img = make_gradient_8x8()
  let hash = dhash(img)
  assert_eq(hash.length(), 64)
}

///|
test "dhash: horizontal gradient produces 0s (increasing)" {
  let img = make_gradient_8x8()
  let hash = dhash(img)
  // dhash: hash=1 if left > right. Increasing gradient → left < right → 0
  let mut zeros = 0
  for i in 0..<64 {
    if hash[i] == 0 {
      zeros += 1
    }
  }
  // All 64 should be 0 for strictly increasing gradient
  assert_eq(zeros, 64)
}

///|
test "phash: returns 64-element hash" {
  let img = make_gradient_8x8()
  let hash = phash(img)
  assert_eq(hash.length(), 64)
}

///|
test "hamming_distance: identical hashes" {
  let h1 = [1, 0, 1, 0, 1, 1, 0, 0]
  let h2 = [1, 0, 1, 0, 1, 1, 0, 0]
  assert_eq(hamming_distance(h1, h2), 0)
}

///|
test "hamming_distance: completely different" {
  let h1 = [1, 1, 1, 1]
  let h2 = [0, 0, 0, 0]
  assert_eq(hamming_distance(h1, h2), 4)
}

///|
test "hamming_distance: partial difference" {
  let h1 = [1, 0, 1, 0, 1, 1, 0, 0]
  let h2 = [1, 1, 1, 0, 0, 1, 0, 1]
  // Differ at positions 1, 4, 7 → distance 3
  assert_eq(hamming_distance(h1, h2), 3)
}

///|
test "ahash + hamming: same image has distance 0" {
  let img = make_gradient_8x8()
  let h1 = ahash(img)
  let h2 = ahash(img)
  assert_eq(hamming_distance(h1, h2), 0)
}
