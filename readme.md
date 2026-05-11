# Dependencies not included
- wayland devel stuff
- vulkan stuff
- slangc

# Layer rerender scheduling
when a layer is dirty, it tell the compositor `.markDirty(node: self)` the compositor will then acquire a frame. when acquired, `animationFrameCallback`s are fired. After that it will read its `dirtyNodes` list (which might be mutate duraion animation frame) then start rendering task.

The presence of an `animationFrameCallback` will force the compositor to actively acquire a frame.

## TODO
- optimized computed dirty masking
- new property wrapper: behave like signal but allow linking
- padding, margin
- clip
- think about pixel perfect stuff
- use `libharfbuzz-gpu`
- windows resize (wayland)
- transparency on windows: DirectComposition swapchain
- multi windows support