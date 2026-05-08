# Dependencies not included
- wayland devel stuff
- freetype
- vulkan header

## Shader compiler
use [naga](https://github.com/gfx-rs/wgpu/tree/trunk/naga) to compile wgsl to spirv

ok, it doesnt support push constant, use glslc instead

## TODO
- padding, margin
- clip to parent
- clip
- think about pixel perfect stuff
- distance field of composited(?) shape
- use `libharfbuzz-gpu`
    - so nuke `pango`
- make this run on windows
- unfuck threading -> remove @MainActor

## Note
- query required gpu features (and optionally provide fallback)
    - VK_EXT_blend_operation_advanced is not supported on my machine (or any amd card) 

