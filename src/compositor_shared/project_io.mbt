///|
/// Project file IO for the `.comp` JSON format.
///
/// The core is pure, so it only converts between `Model` and JSON text;
/// reading and writing bytes on disk or in the browser is the platform
/// layer's responsibility. Rasters are embedded as base64 strings to keep
/// the file compact.
///
/// Decoding uses MoonBit's raised-error model: helpers `raise
/// ProjectDecodeError`, and the public entry converts that into a first-class
/// `Result` via `Ok(..) catch { .. }`.

/// A malformed `.comp` document.
suberror ProjectDecodeError {
  ProjectDecodeError(String)
} derive(@debug.Debug)

pub extend ProjectDecodeError with @debug.Debug::{ to_repr }

fn fail[T](message : String) -> T raise ProjectDecodeError {
  raise ProjectDecodeError(message)
}

// ---------------------------------------------------------------------------
// JSON value accessors (raising)
// ---------------------------------------------------------------------------

fn as_object(json : Json) -> Map[String, Json] raise ProjectDecodeError {
  match json {
    Object(map) => map
    _ => fail("expected object")
  }
}

fn as_array(json : Json) -> Array[Json] raise ProjectDecodeError {
  match json {
    Array(items) => items
    _ => fail("expected array")
  }
}

fn as_double(json : Json) -> Double raise ProjectDecodeError {
  match json {
    Number(value) => value
    _ => fail("expected number")
  }
}

fn as_int(json : Json) -> Int raise ProjectDecodeError {
  as_double(json).round().to_int()
}

fn as_string(json : Json) -> String raise ProjectDecodeError {
  match json {
    String(value) => value
    _ => fail("expected string")
  }
}

fn as_bool(json : Json) -> Bool raise ProjectDecodeError {
  match json {
    True => true
    False => false
    _ => fail("expected boolean")
  }
}

/// Require a key in an object map.
fn req(map : Map[String, Json], key : String) -> Json raise ProjectDecodeError {
  match map.get(key) {
    Some(value) => value
    None => fail("missing key: \{key}")
  }
}

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

fn jint(value : Int) -> Json {
  Json::number(value.to_double())
}

fn jdouble(value : Double) -> Json {
  Json::number(value)
}

fn jbool(value : Bool) -> Json {
  Json::boolean(value)
}

fn jstring(value : String) -> Json {
  Json::string(value)
}

fn encode_mask(mask : Mask) -> Json {
  Json::object({
    "width": jint(mask.width),
    "height": jint(mask.height),
    "data": jstring(@base64.encode(mask.data)),
  })
}

fn encode_layer(layer : Layer) -> Json {
  Json::object({
    "id": jint(layer.id),
    "name": jstring(layer.name),
    "visible": jbool(layer.visible),
    "opacity": jdouble(layer.opacity),
    "blend": jstring(layer.blend.to_keyword()),
    "image":
      match layer.image {
        Some(image) => jstring(@base64.encode(image))
        None => Json::null()
      },
    "mask":
      match layer.mask {
        Some(mask) => encode_mask(mask)
        None => Json::null()
      },
  })
}

///|
/// Serialize a model into `.comp` JSON text.
pub fn encode_project(model : Model, indent? : Int) -> String {
  let project = Json::object({
    "format": jstring("compositor"),
    "version": jint(1),
    "width": jint(model.width),
    "height": jint(model.height),
    "active_layer":
      match model.active_layer {
        Some(id) => jint(id)
        None => Json::null()
      },
    "layers": Json::array(Array::map(model.layers, encode_layer)),
  })
  project.stringify(indent=match indent {
    Some(value) => value
    None => 2
  })
}

// ---------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------

fn decode_mask(json : Json) -> Mask raise ProjectDecodeError {
  let map = as_object(json)
  let width = as_int(req(map, "width"))
  let height = as_int(req(map, "height"))
  let b64 = as_string(req(map, "data"))
  { width, height, data: @base64.decode_lossy(b64) }
}

fn decode_layer(json : Json) -> Layer raise ProjectDecodeError {
  let map = as_object(json)
  let id = as_int(req(map, "id"))
  let name = match map.get("name") {
    Some(value) => as_string(value)
    None => "Layer \{id}"
  }
  let visible = match map.get("visible") {
    Some(value) => as_bool(value)
    None => true
  }
  let opacity = match map.get("opacity") {
    Some(value) => as_double(value)
    None => 1.0
  }
  let blend = match map.get("blend") {
    Some(value) => BlendMode::from_keyword(as_string(value))
    None => Normal
  }
  let image = match map.get("image") {
    Some(value) =>
      match value {
        String(b64) => Some(@base64.decode_lossy(b64))
        Null => None
        _ => fail("image must be a string or null")
      }
    None => None
  }
  let mask = match map.get("mask") {
    Some(value) =>
      match value {
        Object(_) => Some(decode_mask(value))
        Null => None
        _ => fail("mask must be an object or null")
      }
    None => None
  }
  { id, name, visible, opacity, blend, image, mask }
}

///|
/// Parse `.comp` JSON text into a document snapshot.
pub fn decode_project(text : StringView) -> Result[Snapshot, ProjectDecodeError] {
  Ok({
    // Convert a JSON parse error into our project error type.
    let json = @json.parse(text) catch {
      e => raise ProjectDecodeError(e.to_string())
    }
    let map = as_object(json)
    let width = as_int(req(map, "width"))
    let height = as_int(req(map, "height"))
    let active_layer = match map.get("active_layer") {
      Some(value) =>
        match value {
          Number(_) => Some(as_int(value))
          Null => None
          _ => None
        }
      None => None
    }
    let items = as_array(req(map, "layers"))
    let layers = []
    for item in items {
      layers.push(decode_layer(item))
    }
    { width, height, layers, active_layer }
  }) catch {
    ProjectDecodeError(message) => Err(ProjectDecodeError(message))
  }
}
