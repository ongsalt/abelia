#ifdef _WIN32
#include "d3d12_presenter.hpp"
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>

extern "C" {
void *_Nonnull d3d12_presenter_new(uint32_t width, uint32_t height, HWND hwnd,
                                   uint32_t image_count) {
  D3D12Presenter *handle = new D3D12Presenter(width, height, hwnd, image_count);
  return (void *)handle;
}

D3D12Images d3d12_presenter_get_images(void *_Nonnull handle) {
  auto presenter = (D3D12Presenter *)handle;
  try {
    return presenter->Images();
  } catch (const std::runtime_error &e) {
    std::cout << "Error: " << e.what() << std::endl;
    std::exit(-1);
  }
}

HANDLE d3d12_presenter_get_fence(void *_Nonnull handle) {
  auto presenter = (D3D12Presenter *)handle;
  return presenter->Fence();
}

void d3d12_presenter_wait(void *_Nonnull handle) {
  auto presenter = (D3D12Presenter *)handle;
  presenter->Wait();
}

int d3d12_presenter_submit(void *_Nonnull handle, int imageIndex,
                           uint64_t renderDoneValue, uint64_t copyDoneValue) {
  auto presenter = (D3D12Presenter *)handle;
  presenter->Present(imageIndex, renderDoneValue, copyDoneValue);
  return 0;
}

int d3d12_presenter_resize(void *_Nonnull handle, uint32_t width,
                           uint32_t height, uint64_t currentFenceValue) {
  auto presenter = (D3D12Presenter *)handle;
  presenter->Resize(width, height, currentFenceValue);
  return 0;
}
}
#endif