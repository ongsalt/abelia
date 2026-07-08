#pragma once

// The contract handed from the D3D12 side to the Vulkan side so Vulkan can
// import D3D12-owned resources and share a timeline with the D3D12 queue.
//
// All handles are NT handles owned by the D3D12 side (kept alive for the
// program's lifetime); Vulkan duplicates them internally on import.

#include <windows.h>

#include <cstdint>

struct SharedInterop {
    LUID     adapterLuid;  // GPU the D3D12 device runs on; Vulkan must match it
    HANDLE   image;        // shared B8G8R8A8_UNORM texture Vulkan renders into
    HANDLE   fence;        // shared D3D12 fence, used as a cross-API timeline
    uint32_t width;
    uint32_t height;
};
