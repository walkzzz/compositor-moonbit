///|
test "hough_circles: detects circle in synthetic image" {
  // 21x21 image with a circle of radius 8 centered at (10, 10)
  let data : Array[Byte] = Array::make(441, b'\x00')
  for y in 0..<21 {
    for x in 0..<21 {
      let dx = x - 10
      let dy = y - 10
      let dist = Float::from_int(dx * dx + dy * dy).sqrt().to_int()
      if dist >= 7 && dist <= 9 {
        data[y * 21 + x] = b'\xFF'
      }
    }
  }
  let img = @types.Image::{
    width: 21,
    height: 21,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let circles = hough_circles(
    img,
    dp=1,
    min_dist=5,
    param1=50,
    param2=10,
    min_radius=5,
    max_radius=12,
  )
  // Should detect at least one circle near center
  assert_true(circles.length() > 0)
  let mut found_center = false
  for c in circles {
    if (c.x - 10).abs() <= 3 && (c.y - 10).abs() <= 3 {
      found_center = true
    }
  }
  assert_true(found_center)
}

///|
test "hough_circles: empty image returns no circles" {
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x00')),
  }
  let circles = hough_circles(
    img,
    dp=1,
    min_dist=5,
    param1=50,
    param2=10,
    min_radius=3,
    max_radius=8,
  )
  assert_eq(circles.length(), 0)
}

///|
test "hough_circles: flat image returns no circles" {
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x80')),
  }
  let circles = hough_circles(
    img,
    dp=1,
    min_dist=5,
    param1=50,
    param2=10,
    min_radius=3,
    max_radius=8,
  )
  assert_eq(circles.length(), 0)
}

///|
test "Circle struct: fields accessible" {
  let c = Circle::{ x: 5, y: 10, radius: 3, votes: 42 }
  assert_eq(c.x, 5)
  assert_eq(c.y, 10)
  assert_eq(c.radius, 3)
  assert_eq(c.votes, 42)
}
