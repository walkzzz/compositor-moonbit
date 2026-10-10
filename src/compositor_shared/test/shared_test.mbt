/// Black-box tests for the shared core, exercising only its public API.

fn solid_rgba(
  w : Int,
  h : Int,
  r : Byte,
  g : Byte,
  b : Byte,
  a : Byte,
) -> Bytes {
  let arr = Array::make(w * h * 4, Int::to_byte(0))
  for i in 0..<(w * h) {
    arr[i * 4] = r
    arr[i * 4 + 1] = g
    arr[i * 4 + 2] = b
    arr[i * 4 + 3] = a
  }
  Bytes::from_array(arr)
}

fn near(v : Int, target : Int, tol : Int) -> Bool {
  v >= target - tol && v <= target + tol
}

fn gray_layer(
  id : Int,
  w : Int,
  h : Int,
  v : Int,
  blend : @S.BlendMode,
) -> @S.Layer {
  let b = Int::to_byte(v)
  {
    id,
    name: "layer\{id}",
    visible: true,
    opacity: 1.0,
    blend,
    image: Some(solid_rgba(w, h, b, b, b, Int::to_byte(255))),
    mask: None,
    offset_x: 0.0,
    offset_y: 0.0,
  }
}

fn two_layer_model(
  top_blend : @S.BlendMode,
  base_v : Int,
  top_v : Int,
) -> @S.Model {
  let m = @S.init_model(2, 2)
  {
    ..m,
    layers: [
      gray_layer(0, 2, 2, base_v, @S.BlendMode::Normal),
      gray_layer(1, 2, 2, top_v, top_blend),
    ],
    active_layer: Some(1),
    next_id: 2,
  }
}

test "init model is a single opaque white layer" {
  let m = @S.init_model(4, 4)
  assert_eq(m.layers.length(), 1)
  let flat = @S.flatten(m)
  assert_eq(flat.length(), 4 * 4 * 4)
  for i in 0..<(4 * 4) {
    assert_eq(flat[i * 4], 255)
    assert_eq(flat[i * 4 + 3], 255)
  }
}

test "add layer grows stack and is selected" {
  let m = @S.update(@S.init_model(4, 4), @S.Msg::AddLayer)
  assert_eq(m.layers.length(), 2)
  assert_eq(m.active_layer, Some(1))
}

test "undo and redo restore layer count" {
  let m1 = @S.update(@S.init_model(4, 4), @S.Msg::AddLayer)
  let m2 = @S.update(m1, @S.Msg::Undo)
  assert_eq(m2.layers.length(), 1)
  let m3 = @S.update(m2, @S.Msg::Redo)
  assert_eq(m3.layers.length(), 2)
}

test "multiply over white reproduces the top gray" {
  let flat = @S.flatten(two_layer_model(@S.BlendMode::Multiply, 255, 128))
  assert_true(near(flat[0].to_int(), 128, 1))
}

test "screen over black reproduces the top gray" {
  let flat = @S.flatten(two_layer_model(@S.BlendMode::Screen, 0, 128))
  assert_true(near(flat[0].to_int(), 128, 1))
}

test "brush stroke paints and is undoable" {
  let black : @S.Brush = {
    size: 3.0,
    hardness: 1.0,
    opacity: 1.0,
    color: @S.Color::{ r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
  }
  let m1 = { ..@S.init_model(8, 8), brush: black }
  let m2 = @S.update(m1, @S.Msg::BrushStart(4.0, 4.0))
  let m3 = @S.update(m2, @S.Msg::BrushEnd)
  let idx = (4 * 8 + 4) * 4
  assert_eq(@S.flatten(m3)[idx], 0)
  let m4 = @S.update(m3, @S.Msg::Undo)
  assert_eq(@S.flatten(m4)[idx], 255)
}

test "black mask hides the layer" {
  let layer : @S.Layer = {
    ..gray_layer(0, 4, 4, 255, @S.BlendMode::Normal),
    mask: Some(@S.Mask::black(4, 4)),
  }
  let m = { ..@S.init_model(4, 4), layers: [layer], active_layer: Some(0) }
  assert_eq(@S.flatten(m)[3], 0)
}

test "project encode/decode round-trips" {
  let m1 = @S.update(@S.init_model(4, 4), @S.Msg::AddLayer)
  let json = @S.encode_project(m1)
  match @S.decode_project(json) {
    Ok(_) => {
      let restored = @S.update(m1, @S.Msg::ProjectLoaded(json))
      assert_eq(restored.layers.length(), 2)
      assert_eq(@S.flatten(restored), @S.flatten(m1))
    }
    Err(_) => fail("decode failed")
  }
}

test "decode rejects malformed json" {
  match @S.decode_project("not json") {
    Err(_) => assert_true(true)
    Ok(_) => fail("expected decode error")
  }
}

test "brightness and contrast run" {
  let m = @S.update(
    @S.update(@S.init_model(4, 4), @S.Msg::AdjustBrightness(0.2)),
    @S.Msg::AdjustContrast(1.2),
  )
  assert_eq(m.layers.length(), 1)
}

test "eraser reduces alpha" {
  let black : @S.Brush = {
    size: 3.0,
    hardness: 1.0,
    opacity: 1.0,
    color: @S.Color::{ r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
  }
  let m1 = { ..@S.init_model(8, 8), brush: black }
  // Paint black, then erase the same spot.
  let m2 = @S.update(m1, @S.Msg::BrushStart(4.0, 4.0))
  let m3 = @S.update(m2, @S.Msg::BrushEnd)
  let idx = (4 * 8 + 4) * 4
  assert_eq(@S.flatten(m3)[idx + 3], 255) // opaque after paint
  let m4 = { ..m3, tool: @S.Tool::Eraser }
  let m5 = @S.update(m4, @S.Msg::BrushStart(4.0, 4.0))
  let m6 = @S.update(m5, @S.Msg::BrushEnd)
  assert_eq(@S.flatten(m6)[idx + 3], 0) // transparent after erase
}

test "flood fill replaces connected region" {
  // Create a 4x4 image: top-left 2x2 red, rest white.
  let arr = Array::make(4 * 4 * 4, Int::to_byte(0))
  for y in 0..<4 {
    for x in 0..<4 {
      let i = (y * 4 + x) * 4
      if x < 2 && y < 2 {
        arr[i] = 255
        arr[i + 1] = 0
        arr[i + 2] = 0
        arr[i + 3] = 255
      } else {
        arr[i] = 255
        arr[i + 1] = 255
        arr[i + 2] = 255
        arr[i + 3] = 255
      }
    }
  }
  let image = Bytes::from_array(arr)
  let filled = @S.flood_fill(image, 4, 4, 0, 0, @S.Color::rgb(0.0, 1.0, 0.0))
  // Pixel (0,0) should now be green.
  assert_eq(filled[0], 0)
  assert_eq(filled[1], 255)
  assert_eq(filled[2], 0)
  // Pixel (2,0) should still be white (different region).
  assert_eq(filled[(0 * 4 + 2) * 4], 255)
  assert_eq(filled[(0 * 4 + 2) * 4 + 1], 255)
}

test "gaussian blur softens edges" {
  // Create a 5x1 image: left half black, right half white.
  let arr = Array::make(5 * 4, Int::to_byte(0))
  for x in 0..<5 {
    let i = x * 4
    if x < 2 {
      arr[i] = 0
      arr[i + 1] = 0
      arr[i + 2] = 0
      arr[i + 3] = 255
    } else {
      arr[i] = 255
      arr[i + 1] = 255
      arr[i + 2] = 255
      arr[i + 3] = 255
    }
  }
  let image = Bytes::from_array(arr)
  let blurred = @S.gaussian_blur(image, 5, 1, 2.0)
  // The boundary pixel (index 2) should be a mid-gray, not pure black or white.
  let v = blurred[2 * 4].to_int()
  assert_true(v > 10 && v < 245)
}

test "layer offset shifts compositing" {
  let m = @S.init_model(4, 4)
  // Shift the background layer by (1, 0).
  let m1 = @S.update(m, @S.Msg::SetLayerOffset(0, 1.0, 0.0))
  let flat = @S.flatten(m1)
  // Pixel (0, y) should now be transparent (background shifted right).
  assert_eq(flat[3], 0)
  // Pixel (1, y) should be white (background now covers it).
  assert_eq(flat[(0 * 4 + 1) * 4], 255)
}
