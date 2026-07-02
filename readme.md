# Abelia
ui library.

# Hardware requirement
- Vulkan >= 1.3 with `dynamic_rendering_local_read`, no fallback path yet
    - VK_EXT_rasterization_order_attachment_access


## Dependencies not included
- Vulkan header (for vma, might expose this from `swift-vulkan` later)

## Dev dependencies
- `slangc > v2026.12.1` (cuz it has weird `nonuniformExt` bug)

### Fedora
```bash
sudo dnf install vulkan-headers
```