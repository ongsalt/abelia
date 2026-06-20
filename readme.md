# Abelia
2d Graphics Library + UI?

## Dependencies not included
- Vulkan header (for vma, might expose this from `swift-vulkan` later)
- `slangc` (only need if shaders were modified)

### Fedora
```bash
sudo dnf copr enable rustyclanker/slang
sudo dnf install shader-slang shader-slang-libs shader-slang-devel
```