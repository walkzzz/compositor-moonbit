///|
/// The TEA update function and per-message handlers.
///
/// `update` is a pure function: given the current model and a message it
/// returns the next model. Mutating handlers record history first via
/// `push_history` so each user action is one undo step.

///|
/// Create an editor model with a single opaque white background layer.
pub fn init_model(width : Int, height : Int) -> Model {
  let w = if width > 0 { width } else { 1 }
  let h = if height > 0 { height } else { 1 }
  let background : Layer = {
    id: 0,
    name: "Background",
    visible: true,
    opacity: 1.0,
    blend: Normal,
    image: Some(solid_rgba(w, h, Color::rgb(1.0, 1.0, 1.0))),
    mask: None,
    offset_x: 0.0,
    offset_y: 0.0,
  }
  {
    width: w,
    height: h,
    layers: [background],
    active_layer: Some(0),
    tool: Brush,
    brush: Brush::default(),
    next_id: 1,
    drawing: false,
    last_x: 0.0,
    last_y: 0.0,
    undo: [],
    redo: [],
  }
}

///|
/// Find the array index of a layer by id.
fn layer_index(model : Model, id : Int) -> Int? {
  let mut found = None
  let count = model.layers.length()
  for i in 0..<count {
    if model.layers[i].id == id {
      found = Some(i)
    }
  }
  found
}

///|
/// Return a model with one layer (selected by id) replaced by `f(layer)`.
fn map_layer(model : Model, id : Int, f : (Layer) -> Layer) -> Model {
  let layers = Array::map(model.layers, layer => {
    if layer.id == id {
      f(layer)
    } else {
      layer
    }
  })
  { ..model, layers, }
}

///|
/// Apply a change to the active layer, recording history first.
fn with_active_layer(model : Model, f : (Layer) -> Layer) -> Model {
  match model.active_layer {
    Some(id) => map_layer(push_history(model), id, f)
    None => model
  }
}

// ---------------------------------------------------------------------------
// Layer handlers
// ---------------------------------------------------------------------------

///|
fn add_layer(model : Model) -> Model {
  let model = push_history(model)
  let id = model.next_id
  let layer = Layer::transparent(id, "Layer \{id}", model.width, model.height)
  let layers = Array::copy(model.layers)
  layers.push(layer)
  { ..model, layers, active_layer: Some(id), next_id: id + 1, }
}

///|
fn duplicate_layer(model : Model, id : Int) -> Model {
  match layer_index(model, id) {
    Some(index) => {
      let model = push_history(model)
      let original = model.layers[index]
      let new_id = model.next_id
      let copy : Layer = {
        ..original,
        id: new_id,
        name: original.name + " copy",
      }
      let layers = []
      let n = model.layers.length()
      for i in 0..<n {
        layers.push(model.layers[i])
        if i == index {
          layers.push(copy)
        }
      }
      { ..model, layers, active_layer: Some(new_id), next_id: new_id + 1, }
    }
    None => model
  }
}

///|
fn delete_layer(model : Model, id : Int) -> Model {
  match layer_index(model, id) {
    Some(index) =>
      if model.layers.length() <= 1 {
        // Keep at least one layer.
        model
      } else {
        let model = push_history(model)
        let layers = Array::copy(model.layers)
        ignore(layers.remove(index))
        let neighbor = if index > 0 { index - 1 } else { 0 }
        let active_layer = match model.active_layer {
          Some(active) if active == id => Some(layers[neighbor].id)
          other => other
        }
        { ..model, layers, active_layer, }
      }
    None => model
  }
}

///|
fn move_layer(model : Model, id : Int, up : Bool) -> Model {
  match layer_index(model, id) {
    Some(index) => {
      let target = if up { index + 1 } else { index - 1 }
      if target < 0 || target >= model.layers.length() {
        model
      } else {
        let model = push_history(model)
        let layers = Array::copy(model.layers)
        let tmp = layers[index]
        layers[index] = layers[target]
        layers[target] = tmp
        { ..model, layers, }
      }
    }
    None => model
  }
}

///|
fn add_mask(model : Model, id : Int) -> Model {
  map_layer(push_history(model), id, layer => {
    match layer.mask {
      None => { ..layer, mask: Some(Mask::white(model.width, model.height)), }
      Some(_) => layer
    }
  })
}

///|
fn remove_mask(model : Model, id : Int) -> Model {
  map_layer(push_history(model), id, layer => { ..layer, mask: None, })
}

// ---------------------------------------------------------------------------
// Painting handlers
// ---------------------------------------------------------------------------

///|
/// Begin a stroke; the whole stroke becomes a single undo step.
fn brush_start(model : Model, x : Double, y : Double) -> Model {
  match model.active_layer {
    Some(id) => {
      let model = push_history(model)
      let model = { ..model, drawing: true, last_x: x, last_y: y, }
      apply_paint(model, id, x, y, x, y)
    }
    None => model
  }
}

///|
fn brush_move(model : Model, x : Double, y : Double) -> Model {
  if model.drawing && model.active_layer is Some(id) {
    let model = apply_paint(model, id, model.last_x, model.last_y, x, y)
    { ..model, last_x: x, last_y: y, }
  } else {
    model
  }
}

///|
/// Paint one interpolated segment either to the layer image or its mask
/// depending on the active tool.
fn apply_paint(
  model : Model,
  id : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Model {
  map_layer(model, id, layer => {
    match model.tool {
      MaskBrush =>
        match layer.mask {
          Some(mask) => {
            // Mask brush paints white (reveal) in the prototype.
            let updated = paint_segment_mask(
              mask,
              x0,
              y0,
              x1,
              y1,
              model.brush,
              255,
            )
            { ..layer, mask: Some(updated), }
          }
          None => layer
        }
      Eraser =>
        match layer.image {
          Some(image) => {
            let updated = erase_segment_rgba(
              image,
              model.width,
              model.height,
              x0,
              y0,
              x1,
              y1,
              model.brush,
            )
            { ..layer, image: Some(updated), }
          }
          None => layer
        }
      _ =>
        match layer.image {
          Some(image) => {
            let updated = paint_segment_rgba(
              image,
              model.width,
              model.height,
              x0,
              y0,
              x1,
              y1,
              model.brush,
            )
            { ..layer, image: Some(updated), }
          }
          None => layer
        }
    }
  })
}

// ---------------------------------------------------------------------------
// Adjustment handlers
// ---------------------------------------------------------------------------

///|
fn adjust_active(model : Model, f : (Bytes) -> Bytes) -> Model {
  with_active_layer(model, layer => {
    match layer.image {
      Some(image) => { ..layer, image: Some(f(image)), }
      None => layer
    }
  })
}

///|
/// Flood-fill the active layer at the given pointer position with the brush
/// color.  Records history first.
fn fill_at(model : Model, x : Double, y : Double) -> Model {
  match model.active_layer {
    Some(id) =>
      map_layer(push_history(model), id, layer => {
        match layer.image {
          Some(image) => {
            let px = x.floor().to_int()
            let py = y.floor().to_int()
            let filled = flood_fill(
              image,
              model.width,
              model.height,
              px,
              py,
              model.brush.color,
            )
            { ..layer, image: Some(filled), }
          }
          None => layer
        }
      })
    None => model
  }
}

// ---------------------------------------------------------------------------
// Image import / project loaded
// ---------------------------------------------------------------------------

///|
/// Open a decoded RGBA image. The canvas adopts the image dimensions and the
/// image becomes the single document layer with cleared history.
fn import_image(
  name : String,
  width : Int,
  height : Int,
  rgba : Bytes,
) -> Model {
  let layer : Layer = {
    id: 0,
    name,
    visible: true,
    opacity: 1.0,
    blend: Normal,
    image: Some(rgba),
    mask: None,
    offset_x: 0.0,
    offset_y: 0.0,
  }
  {
    width,
    height,
    layers: [layer],
    active_layer: Some(0),
    tool: Brush,
    brush: Brush::default(),
    next_id: 1,
    drawing: false,
    last_x: 0.0,
    last_y: 0.0,
    undo: [],
    redo: [],
  }
}

///|
fn project_loaded(model : Model, json : String) -> Model {
  match decode_project(json) {
    Ok(project) =>
      {
        ..model,
        width: project.width,
        height: project.height,
        layers: project.layers,
        active_layer: project.active_layer,
        drawing: false,
        undo: [],
        redo: [],
      }
    Err(_) => model
  }
}

// ---------------------------------------------------------------------------
// Main entry
// ---------------------------------------------------------------------------

///|
/// Apply a message to the model and return the next model.
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    NewCanvas(width, height) => init_model(width, height)
    ProjectLoaded(json) => project_loaded(model, json)
    ImportImage(name, width, height, rgba) =>
      import_image(name, width, height, rgba)
    AddLayer => add_layer(model)
    DuplicateLayer(id) => duplicate_layer(model, id)
    DeleteLayer(id) => delete_layer(model, id)
    SelectLayer(id) => { ..model, active_layer: Some(id), }
    ToggleLayerVisible(id) =>
      map_layer(push_history(model), id, layer => {
        ..layer,
        visible: !layer.visible,
      })
    RenameLayer(id, name) =>
      map_layer(push_history(model), id, layer => { ..layer, name, })
    MoveLayerUp(id) => move_layer(model, id, true)
    MoveLayerDown(id) => move_layer(model, id, false)
    SetLayerBlend(id, blend) =>
      map_layer(push_history(model), id, layer => { ..layer, blend, })
    SetLayerOpacity(id, opacity) =>
      map_layer(push_history(model), id, layer => {
        ..layer,
        opacity: clamp01(opacity),
      })
    SetLayerOffset(id, dx, dy) =>
      map_layer(push_history(model), id, layer => {
        ..layer,
        offset_x: dx,
        offset_y: dy,
      })
    AddMask(id) => add_mask(model, id)
    RemoveMask(id) => remove_mask(model, id)
    SetTool(tool) => { ..model, tool, }
    SetBrushSize(size) =>
      { ..model, brush: { ..model.brush, size: dmax(size, 1.0), }, }
    SetBrushOpacity(opacity) =>
      { ..model, brush: { ..model.brush, opacity: clamp01(opacity), }, }
    SetBrushHardness(hardness) =>
      { ..model, brush: { ..model.brush, hardness: clamp01(hardness), }, }
    SetBrushColor(color) => { ..model, brush: { ..model.brush, color, }, }
    BrushStart(x, y) => brush_start(model, x, y)
    BrushMove(x, y) => brush_move(model, x, y)
    BrushEnd => { ..model, drawing: false, }
    FillAt(x, y) => fill_at(model, x, y)
    AdjustBrightness(amount) =>
      adjust_active(model, image => adjust_brightness(image, amount))
    AdjustContrast(amount) =>
      adjust_active(model, image => adjust_contrast(image, amount))
    AdjustHue(degrees) =>
      adjust_active(model, image => adjust_hue(image, degrees))
    AdjustSaturation(amount) =>
      adjust_active(model, image => adjust_saturation(image, amount))
    AdjustBlur(radius) =>
      adjust_active(model, image => {
        gaussian_blur(image, model.width, model.height, radius)
      })
    AdjustSharpen(amount) =>
      adjust_active(model, image => {
        sharpen(image, model.width, model.height, amount)
      })
    AdjustEdgeDetect =>
      adjust_active(model, image => {
        edge_detect_sobel(image, model.width, model.height)
      })
    AdjustInvert => adjust_active(model, image => invert(image))
    AdjustGrayscale => adjust_active(model, image => grayscale(image))
    AdjustSepia => adjust_active(model, image => sepia(image))
    Undo => undo(model)
    Redo => redo(model)

    // File side effects are performed by the platform layer, not the core.
    RequestSaveProject(_) => model
    RequestLoadProject(_) => model
    RequestExportImage(_) => model
  }
}
