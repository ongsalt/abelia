# Graphics 101

## Dependencies not included
- vulkan header
- slangc (only need if shaders were modified)

## Layer rerender scheduling
when a layer is dirty, it tell the compositor `.markDirty(node: self)` the compositor will then acquire a frame. when acquired, `animationFrameCallback`s are fired. After that it will read its `dirtyNodes` list (which might be mutate duraion animation frame) then start rendering task.

The presence of an `animationFrameCallback` will force the compositor to actively acquire a frame.

## TODO
- nuke async code
- write the actual shader
- actually read from layerStorage

- optimize computed dirty flagging
- new property wrapper: behave like signal but allow linking
- clip
- think about pixel perfect stuff
- `libharfbuzz-gpu`
- `blend2d` for canvas api
  - and font rendering (for now)
- windows resize (wayland)
- transparency on windows: DirectComposition swapchain
- multi windows support