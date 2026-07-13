#ifdef _WIN32

#include <stdint.h>
#include <windows.h>

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t image_count;
  HANDLE image1;
  HANDLE image2;
  HANDLE image3;
} D3D12Images;

void *_Nonnull d3d12_presenter_new(uint32_t width, uint32_t height, HWND hwnd,
                                   uint32_t image_count);
// waits for the shared fence to reach `currentFenceValue` first
void d3d12_presenter_destroy(void *_Nonnull handle,
                             uint64_t currentFenceValue);
D3D12Images d3d12_presenter_get_images(void *_Nonnull handle);

HANDLE d3d12_presenter_get_fence(void *_Nonnull handle);

// wait for dxgi
void d3d12_presenter_wait(void *_Nonnull handle);

// wait for fence
void d3d12_presenter_wait_value(void *_Nonnull handle, uint64_t value);

int d3d12_presenter_present(void *_Nonnull handle, uint32_t imageIndex,
                            uint64_t renderDoneValue, uint64_t copyDoneValue);

int d3d12_presenter_resize(void *_Nonnull handle, uint32_t width,
                           uint32_t height, uint64_t currentFenceValue);

#endif