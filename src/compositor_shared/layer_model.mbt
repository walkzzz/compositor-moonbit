///|
/// Compositor shared core — data model.
///
/// This package is platform independent. It must never import Proton, Rabbita,
/// a windowing toolkit, or a GPU API. It defines the document model, the TEA
/// messages, the update function, CPU image algorithms, and project IO.
///
/// Design note: raster pixels are stored as the immutable `Bytes` type rather
/// than `Array[Byte]`. `Bytes` has structural equality and shares safely
/// between undo snapshots; pixel code converts to a mutable `Array[Byte]` for
/// editing and back with `Bytes::from_array`.

///|
/// Layer blend modes. The set mirrors the original Compositor's
/// Photoshop-style separable/non-separable modes.
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
} derive(Eq, @debug.Debug)

///|
/// Returns the stable string identifier used when serializing a blend mode in
/// the `.comp` project file.
pub fn BlendMode::to_keyword(self : BlendMode) -> String {
  match self {
    Normal => "normal"
    Multiply => "multiply"
    Screen => "screen"
    Overlay => "overlay"
    Darken => "darken"
    Lighten => "lighten"
    ColorDodge => "color-dodge"
    ColorBurn => "color-burn"
    HardLight => "hard-light"
    SoftLight => "soft-light"
    Difference => "difference"
    Exclusion => "exclusion"
    Hue => "hue"
    Saturation => "saturation"
    Color => "color"
    Luminosity => "luminosity"
  }
}

///|
/// Parses a blend mode keyword. Unknown keywords fall back to `Normal`.
pub fn BlendMode::from_keyword(s : StringView) -> BlendMode {
  match s {
    "normal" => Normal
    "multiply" => Multiply
    "screen" => Screen
    "overlay" => Overlay
    "darken" => Darken
    "lighten" => Lighten
    "color-dodge" => ColorDodge
    "color-burn" => ColorBurn
    "hard-light" => HardLight
    "soft-light" => SoftLight
    "difference" => Difference
    "exclusion" => Exclusion
    "hue" => Hue
    "saturation" => Saturation
    "color" => Color
    "luminosity" => Luminosity
    _ => Normal
  }
}

///|
/// An 8-bit grayscale layer mask. White reveals the layer, black hides it.
pub(all) struct Mask {
  width : Int
  height : Int
  /// Grayscale samples, one byte per pixel, row major, top-left origin.
  data : Bytes
} derive(Eq, @debug.Debug)

///|
/// Construct a fully white (revealing) mask of the given size.
pub fn Mask::white(width : Int, height : Int) -> Mask {
  { width, height, data: Bytes::make(width * height, b"\xff"[0]) }
}

///|
/// Construct a fully black (concealing) mask of the given size.
pub fn Mask::black(width : Int, height : Int) -> Mask {
  { width, height, data: Bytes::make(width * height, b"\x00"[0]) }
}

///|
/// A single document layer.
pub(all) struct Layer {
  id : Int
  name : String
  visible : Bool
  /// Layer opacity in `[0.0, 1.0]`.
  opacity : Double
  blend : BlendMode
  /// RGBA8 samples, four bytes per pixel, row major, top-left origin.
  image : Bytes?
  /// Optional layer mask.
  mask : Mask?
} derive(Eq, @debug.Debug)

///|
/// Build a transparent layer filled with transparent black, sized to canvas.
pub fn Layer::transparent(
  id : Int,
  name : String,
  width : Int,
  height : Int,
) -> Layer {
  {
    id,
    name,
    visible: true,
    opacity: 1.0,
    blend: Normal,
    image: Some(Bytes::new(width * height * 4)),
    mask: None,
  }
}

///|
/// An RGBA color with every channel normalized to `[0.0, 1.0]`.
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, @debug.Debug)

///|
pub fn Color::rgb(r : Double, g : Double, b : Double) -> Color {
  { r, g, b, a: 1.0 }
}

///|
pub fn Color::rgba(r : Double, g : Double, b : Double, a : Double) -> Color {
  { r, g, b, a }
}

///|
/// Brush parameters shared by the brush and mask-brush tools.
pub(all) struct Brush {
  /// Diameter in pixels.
  size : Double
  /// Stroke opacity in `[0.0, 1.0]`.
  opacity : Double
  /// Hardness in `[0.0, 1.0]` (0 = soft feathered edge, 1 = hard edge).
  hardness : Double
  color : Color
} derive(Eq, @debug.Debug)

///|
pub fn Brush::default() -> Brush {
  { size: 20.0, opacity: 1.0, hardness: 0.8, color: Color::rgb(0.0, 0.0, 0.0) }
}

///|
/// The active editing tool.
pub(all) enum Tool {
  Brush
  Move
  MaskBrush
} derive(Eq, @debug.Debug)

///|
/// An immutable document snapshot used by the undo/redo stacks. Storing
/// snapshots (rather than nesting full `Model` values) keeps the type
/// non-recursive and captures only the document content, not the stacks.
pub struct Snapshot {
  width : Int
  height : Int
  layers : Array[Layer]
  active_layer : Int?
} derive(Eq)

///|
/// The global editor state.
pub(all) struct Model {
  width : Int
  height : Int
  layers : Array[Layer]
  active_layer : Int?
  tool : Tool
  brush : Brush
  /// Monotonic counter used to assign fresh layer ids.
  next_id : Int
  /// Whether a stroke is currently in progress.
  drawing : Bool
  /// Last sampled pointer position, used to interpolate a continuous stroke.
  last_x : Double
  last_y : Double
  undo : Array[Snapshot]
  redo : Array[Snapshot]
} derive(Eq)
