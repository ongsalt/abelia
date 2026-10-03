#ifndef CVULKAN_H
#define CVULKAN_H

#if defined(_WIN32)
#	define VK_USE_PLATFORM_WIN32_KHR
#elif defined(__APPLE__)
#	define VK_USE_PLATFORM_METAL_EXT
#elif defined(__linux__)
#	define VK_USE_PLATFORM_WAYLAND_KHR
#endif

#include "../../../Vendors/volk/volk.h"
#include "../../../Vendors/VulkanMemoryAllocator/include/vk_mem_alloc.h"

#endif /* CVULKAN_H */