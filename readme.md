# Graphics 101

## Dependencies not included
- vulkan header
- slangc (only need if shaders were modified)

## Layer rerender scheduling
when a layer is dirty, it tell the compositor `.markDirty(node: self)` the compositor will then acquire a frame. when acquired, `animationFrameCallback`s are fired. After that it will read its `dirtyNodes` list (which might be mutate duraion animation frame) then start rendering task.

The presence of an `animationFrameCallback` will force the compositor to actively acquire a frame.

## TODO
- write the actual shader
  - sdf
  - transformation
- calculate batching
  - make layer storage node per subpass instead
- anti aliasing
- pause rendering if hidden or windows size = 0
- transform DSL: .default
- fix render loop again. also do proper frame in flight
```
vkQueueSubmit2(): THREADING ERROR : object of type VkQueue is simultaneously used in current thread X and thread Y
```

- optimize computed dirty flagging
- new property wrapper: behave like signal but allow linking
- clip
- think about pixel perfect stuff
- `libharfbuzz-gpu`
- a window on wayland
- transparency on windows: DirectComposition swapchain
- multi windows support