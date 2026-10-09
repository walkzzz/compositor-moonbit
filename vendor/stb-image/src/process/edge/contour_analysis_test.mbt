///|
test "convex_hull: square points" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 10, y: 0 },
    ContourPoint::{ x: 10, y: 10 },
    ContourPoint::{ x: 0, y: 10 },
    ContourPoint::{ x: 5, y: 5 },
  ]
  let hull = convex_hull(points)
  // Interior point (5,5) should not be in hull
  assert_eq(hull.length(), 4)
  let mut has_interior = false
  for p in hull {
    if p.x == 5 && p.y == 5 {
      has_interior = true
    }
  }
  assert_false(has_interior)
}

///|
test "convex_hull: triangle" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 10, y: 0 },
    ContourPoint::{ x: 5, y: 10 },
    ContourPoint::{ x: 5, y: 5 },
  ]
  let hull = convex_hull(points)
  assert_eq(hull.length(), 3)
}

///|
test "convex_hull: collinear points" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 5, y: 0 },
    ContourPoint::{ x: 10, y: 0 },
  ]
  let hull = convex_hull(points)
  assert_true(hull.length() <= 3)
}

///|
test "approx_poly_dp: simplifies rectangle" {
  let points : Array[ContourPoint] = []
  for x in 0..<=10 {
    points.push(ContourPoint::{ x, y: 0 })
  }
  for y in 1..<=10 {
    points.push(ContourPoint::{ x: 10, y })
  }
  for k in 0..<10 {
    points.push(ContourPoint::{ x: 9 - k, y: 10 })
  }
  for k in 1..<10 {
    points.push(ContourPoint::{ x: 0, y: 9 - k })
  }
  let simplified = approx_poly_dp(points, 1.0F, closed=true)
  // Should reduce to ~4 corner points
  assert_true(simplified.length() <= 8)
  assert_true(simplified.length() >= 3)
}

///|
test "image_moments: centroid of symmetric points" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 10, y: 0 },
    ContourPoint::{ x: 10, y: 10 },
    ContourPoint::{ x: 0, y: 10 },
  ]
  let m = image_moments(points)
  // Centroid should be at (5, 5)
  let cx = m.m10 / m.m00
  let cy = m.m01 / m.m00
  assert_true((cx - 5.0).abs() < 0.01)
  assert_true((cy - 5.0).abs() < 0.01)
}

///|
test "image_moments: area (m00) equals point count" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 5, y: 3 },
    ContourPoint::{ x: 2, y: 7 },
  ]
  let m = image_moments(points)
  assert_true((m.m00 - 3.0).abs() < 0.01)
}

///|
test "hu_moments: returns 7 values" {
  let points = [
    ContourPoint::{ x: 0, y: 0 },
    ContourPoint::{ x: 10, y: 0 },
    ContourPoint::{ x: 10, y: 10 },
    ContourPoint::{ x: 0, y: 10 },
  ]
  let m = image_moments(points)
  let hu = hu_moments(m)
  assert_eq(hu.length(), 7)
}

///|
test "min_enclosing_circle: single point" {
  let points = [ContourPoint::{ x: 5, y: 3 }]
  let (center, radius) = min_enclosing_circle(points)
  assert_eq(center.x, 5)
  assert_eq(center.y, 3)
  assert_true(radius < 1.0F)
}

///|
test "min_enclosing_circle: two points" {
  let points = [ContourPoint::{ x: 0, y: 0 }, ContourPoint::{ x: 10, y: 0 }]
  let (center, radius) = min_enclosing_circle(points)
  // Center should be near (5, 0), radius near 5
  assert_true((center.x - 5).abs() <= 2)
  assert_true(radius > 3.0F)
}
