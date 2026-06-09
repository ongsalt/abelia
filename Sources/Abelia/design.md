# Flow
- layer was mutated OR requestAnimationFrame 
- tell the renderer we need flush request\
- once it can render -> it will sync main thread, high priority
    - RUN requestAnimationFrame now with `expectedFrameTime` (VK_GOOGLE_display_timing, VK_KHR_present_wait, VK_EXT_present_timing)
    - flush the layer tree
- we are done with main thread, the renderer thread now doing its thing 