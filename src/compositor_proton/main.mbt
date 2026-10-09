///|
/// Native desktop CLI entry (Milestone 0/2 prototype).
///
/// This executable demonstrates the full native pipeline using the STB image
/// binding (walkzzz/image): it reads an image file, decodes it to RGBA, imports
/// it through the shared TEA `update`, flattens the layer stack on the CPU,
/// encodes the composite back to PNG, and prints the `.comp` project JSON.
///
/// Usage:
///   compositor_proton <input.png|jpg|bmp|...> <output.png>
///
/// The later Proton window, menus, and wgpu-native renderer replace this CLI
/// but reuse the same shared `Model`/`update`.
fn usage() -> Unit {
  println("usage: compositor_proton <input image> <output png>")
}

fn main {
  let args = @env.args()
  if args.length() < 3 {
    usage()
  } else {
    let input = args[1]
    let output = args[2]
    try {
      let bytes = @fs.read_file_to_bytes(input)
      let image = @image.load_from_bytes(bytes, req_channels=Some(4))
      let model = @shared.update(
        @shared.init_model(1, 1),
        @shared.Msg::ImportImage(input, image.width, image.height, image.data),
      )
      let composite = @shared.flatten(model)
      let result : @imgtypes.Image = {
        width: model.width,
        height: model.height,
        channels: 4,
        data: composite,
      }
      @fs.write_bytes_to_file(output, @image.write_png_to_bytes(result))
      println("exported composite -> \{output}")
      println(@shared.encode_project(model))
    } catch {
      e => println("error: \{e}")
    }
  }
}
