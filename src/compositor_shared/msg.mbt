///|
/// TEA messages. Every state change in the editor is expressed as a `Msg` and
/// applied by `update`. Both the Proton desktop layer and the Rabbita web
/// layer translate their input events into these same messages.
///
/// File side effects cannot run in the pure core: `RequestSaveProject`,
/// `RequestExportImage`, and `RequestLoadProject` are signals the platform
/// layer interprets. Once a project file is read, the platform sends
/// `ProjectLoaded(json)` so the actual state change still flows through
/// `update`.
pub(all) enum Msg {
  // --- Canvas / document ---
  NewCanvas(Int, Int)
  /// Carries the JSON text produced by reading a `.comp` file.
  ProjectLoaded(String)
  /// Open a decoded image: name, width, height, RGBA8 bytes. The native layer
  /// decodes PNG/JPEG via the STB image binding and sends this message.
  ImportImage(String, Int, Int, Bytes)

  // --- Layer operations ---
  AddLayer
  DuplicateLayer(Int)
  DeleteLayer(Int)
  SelectLayer(Int)
  ToggleLayerVisible(Int)
  RenameLayer(Int, String)
  MoveLayerUp(Int)
  MoveLayerDown(Int)
  SetLayerBlend(Int, BlendMode)
  SetLayerOpacity(Int, Double)
  /// Set the layer pixel offset (dx, dy) applied during compositing.
  SetLayerOffset(Int, Double, Double)

  // --- Mask ---
  AddMask(Int)
  RemoveMask(Int)

  // --- Tools & brush parameters ---
  SetTool(Tool)
  SetBrushSize(Double)
  SetBrushOpacity(Double)
  SetBrushHardness(Double)
  SetBrushColor(Color)

  // --- Pointer / painting ---
  BrushStart(Double, Double)
  BrushMove(Double, Double)
  BrushEnd
  /// Fill the area under the pointer with the brush color (flood fill).
  FillAt(Double, Double)

  // --- Color adjustments ---
  AdjustBrightness(Double)
  AdjustContrast(Double)
  AdjustHue(Double)
  AdjustSaturation(Double)
  /// Gaussian blur with the given radius in pixels.
  AdjustBlur(Double)
  /// Sharpen using unsharp masking; amount controls strength `[0, 2]`.
  AdjustSharpen(Double)
  /// Sobel edge detection; writes grayscale edge magnitude into RGB.
  AdjustEdgeDetect

  // --- History ---
  Undo
  Redo

  // --- File side-effect signals (handled by the platform layer) ---
  RequestSaveProject(String)
  RequestLoadProject(String)
  RequestExportImage(String)
}
