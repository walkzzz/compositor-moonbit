///|
/// Undo/redo history.
///
/// History stores document `Snapshot`s (canvas size, layers, active layer),
/// not full `Model` values. A snapshot is taken before every mutating action.
/// The layers array is copied on capture and again on restore so stored
/// history is never aliased by later edits. The immutable `Bytes` rasters are
/// shared safely without copying pixel memory.

/// Maximum number of retained undo steps.
let undo_limit = 50

/// Capture the current document content.
fn snapshot(model : Model) -> Snapshot {
  {
    width: model.width,
    height: model.height,
    layers: Array::copy(model.layers),
    active_layer: model.active_layer,
  }
}

/// Restore document fields from a snapshot, preserving tool/brush settings.
fn restore_snapshot(model : Model, snap : Snapshot) -> Model {
  {
    ..model,
    width: snap.width,
    height: snap.height,
    layers: Array::copy(snap.layers),
    active_layer: snap.active_layer,
    drawing: false,
  }
}

///|
/// Record the current state into the undo stack before a mutation and clear
/// the redo stack. Mutating update handlers call this first.
pub fn push_history(model : Model) -> Model {
  let mut undo = Array::copy(model.undo)
  undo.push(snapshot(model))
  // Trim the oldest entries once the limit is exceeded.
  if undo.length() > undo_limit {
    let excess = undo.length() - undo_limit
    undo = Array::makei(undo.length() - excess, k => undo[k + excess])
  }
  { ..model, undo, redo: [] }
}

///|
/// Step backward in history.
pub fn undo(model : Model) -> Model {
  match model.undo.last() {
    Some(snap) => {
      // Move the current document state onto the redo stack.
      let redo = Array::copy(model.redo)
      redo.push(snapshot(model))
      let undo = Array::copy(model.undo)
      ignore(undo.pop())
      restore_snapshot({ ..model, undo, redo }, snap)
    }
    None => model
  }
}

///|
/// Step forward in history.
pub fn redo(model : Model) -> Model {
  match model.redo.last() {
    Some(snap) => {
      let undo = Array::copy(model.undo)
      undo.push(snapshot(model))
      let redo = Array::copy(model.redo)
      ignore(redo.pop())
      restore_snapshot({ ..model, undo, redo }, snap)
    }
    None => model
  }
}
