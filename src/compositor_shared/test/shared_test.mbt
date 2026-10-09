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
