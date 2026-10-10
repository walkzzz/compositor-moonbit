# Compositor (MoonBit cross-platform port)

A cross-platform port of the macOS image editor
[Compositor](https://github.com/robbietilton/Compositor) to
[MoonBit](https://www.moonbitlang.com/). One shared core drives native desktop
(Proton) and web (Rabbita) front-ends, with GPU rendering via wgpu.

> OpenHarmony is explicitly out of scope.

## Architecture (TEA / Model-Update-View)

```
src/
  compositor_shared/   # platform-independent core (models, Msg, update, CPU image ops)
    test/              # black-box unit tests
  compositor_proton/   # native desktop (Proton + wgpu-native) — CLI prototype for now
  compositor_rabbita/  # web (Rabbita + WebGPU) — planned
shaders/               # WGSL shaders — planned
vendor/stb-image/      # walkzzz/image STB image binding (native), toadium/stb-image @0.6.0
```

The shared core never imports Proton, Rabbita, windowing or GPU APIs. File IO is
performed by the platform layer; decoded results re-enter through `Msg`.

## Status — Milestone 0.3

- Data model: layers, masks, 16 blend modes, brush, tools, snapshots
- Tools: Brush, Eraser, Fill (flood fill), Move, MaskBrush
- Layer ops: add, duplicate, delete, reorder (up/down), visibility, rename,
  blend mode, opacity, offset
- Pure `update` with full undo/redo history
- CPU brush (hard/soft, interpolated strokes), eraser, flood fill,
  layer compositing/flatten with per-layer offset,
  brightness/contrast/hue/saturation/Gaussian blur/sharpen/Sobel edge detect
- `.comp` project JSON encode/decode (pixels embedded as base64,
  layer offsets persisted)
- Native CLI: decode an image via the STB binding, flatten, export PNG
- Unit tests: 19 passing

## Build & test

Requires the MoonBit toolchain (`moon`).

```sh
moon check src/compositor_shared
moon test  src/compositor_shared/test --target native

# native CLI: read an image, flatten, write PNG (also prints .comp JSON)
moon build src/compositor_proton --target native
./_build/native/debug/build/compositor/compositor-moonbit/src/compositor_proton/compositor_proton.exe input.png output.png
```

## License

Apache-2.0
