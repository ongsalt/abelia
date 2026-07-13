#ifdef _WIN32
#pragma once

// The D3D12 side of the interop. It owns *only* the presentation path:
//   - the device / queue / composition swapchain,
//   - a shared texture that Vulkan renders into,
//   - a shared fence used as a cross-API timeline.
//
// Each frame, once Vulkan has signalled the fence, Present() copies the shared
// texture into the current backbuffer and presents it. No D3D12 rendering.

#include "wil.h"
#include "windows.h"

#include <d3d12.h>
#include <dcomp.h>
#include <dxgi1_6.h>
#include <vector>

extern "C" {
#include "d3d12_presenter_c.h"
}

class D3D12Presenter {
public:
  // TODO: pass device identifier here + and match the device
  D3D12Presenter(uint32_t width, uint32_t height, HWND hwnd, uint32_t image_count);
  ~D3D12Presenter();

  D3D12Images Images();

  HANDLE Fence();
  // return current fence counter
  void Wait();

  // block until the shared fence reaches `value`
  void WaitFence(uint64_t value);

  // allocate to exact
  // might expose a way to do clipping
  void Resize(uint32_t width, uint32_t height, uint64_t currentFenceValue);

  // On the GPU queue: wait until the fence reaches `renderDoneValue` (Vulkan's
  // signal that the shared texture is ready), copy it into the current
  // backbuffer, present, then signal `copyDoneValue` (so Vulkan may reuse the
  // texture).
  void Present(uint32_t imageIndex, uint64_t renderDoneValue,
               uint64_t copyDoneValue);

private:
  void CreateDeviceAndSwapChain();
  void CreateSharedTexture();
  void ReleaseSharedTextures();
  void CreateSharedFence();
  void CreateCompositionTarget();

  void RetireSharedTextures();
  // void FlushRetiredSharedTextures();

  uint32_t width_;
  uint32_t height_;
  uint32_t image_count_;
  HWND hwnd_;
  LUID luid_{};

  // dcomp stuff
  wil::com_ptr<IDCompositionDesktopDevice> composition_device_;
  wil::com_ptr<IDCompositionTarget> target_;
  wil::com_ptr<IDCompositionVisual3> visual_;

  wil::com_ptr<ID3D12Device> device_;
  wil::com_ptr<ID3D12CommandQueue> queue_;
  wil::com_ptr<IDXGISwapChain3> swapChain_;
  std::vector<wil::com_ptr<ID3D12Resource>> backBuffers_;
  std::vector<wil::com_ptr<ID3D12CommandAllocator>> allocators_;
  std::vector<wil::com_ptr<ID3D12GraphicsCommandList>> commandLists_;
  wil::unique_handle _waitable;

  // shared resource
  std::vector<wil::com_ptr<ID3D12Resource>> sharedTextures_;
  std::vector<HANDLE> sharedTextureHandles_;
  wil::com_ptr<ID3D12Fence> fence_;
  wil::unique_handle sharedFenceHandle_;
  wil::unique_event fenceEvent_;

  std::vector<wil::com_ptr<ID3D12Resource>> retiredSharedTextures_;
  std::vector<HANDLE> retiredSharedTextureHandles_;
};

#endif
