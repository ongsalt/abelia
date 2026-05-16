#include <cstdint>
#include <iostream>
#include <ostream>

#define WIN32_LEAN_AND_MEAN
#include <d3d12.h>
#include <dcomp.h>
#include <dxgi1_6.h>
#include <windows.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
    #define EXPORT 
#endif


extern "C" {
  #include "include/wrapper.h"

struct DirectCompositionInteropImpl {
  HWND hwnd;
  ID3D12Device8 *d3D12Device;
  ID3D12CommandAllocator *commandAllocator;
  ID3D12CommandQueue *commandQueue;
  ID3D12GraphicsCommandList *commandList;

  int imageCount;
  ID3D12Resource **importedImages;

  ID3D12Fence *renderFinishedFence;
  ID3D12Fence *copyCompletedFence;
  HANDLE renderFinishedFenceHandle;
  HANDLE copyCompletedFenceHandle;

  IDCompositionDevice3 *dCompDevice;
  IDCompositionTarget *compositionTarget;
  IDCompositionVisual2 *visual;
  IDXGISwapChain3
      *swapChain; // Upgraded to SwapChain3 for GetCurrentBackBufferIndex
  HANDLE frameLatencyWaitableObject;
};

DirectCompositionInterop createDirectCompositionInterop(HWND hwnd,
                                                        int imageCount) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)malloc(
      sizeof(DirectCompositionInteropImpl));
  memset(impl, 0, sizeof(DirectCompositionInteropImpl));

  impl->hwnd = hwnd;
  impl->imageCount = imageCount;

  // Create the D3D12 Device
  HRESULT hr = D3D12CreateDevice(nullptr, D3D_FEATURE_LEVEL_12_0,
                                 IID_PPV_ARGS(&impl->d3D12Device));
  if (FAILED(hr))
    return nullptr;

  // Create Command Queue
  D3D12_COMMAND_QUEUE_DESC commandQueueDesc = {
      .Type = D3D12_COMMAND_LIST_TYPE_DIRECT};
  hr = impl->d3D12Device->CreateCommandQueue(&commandQueueDesc,
                                             IID_PPV_ARGS(&impl->commandQueue));
  if (FAILED(hr))
    return nullptr;

  // Create Command Allocator
  hr = impl->d3D12Device->CreateCommandAllocator(
      D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&impl->commandAllocator));
  if (FAILED(hr))
    return nullptr;

  // Create Command List
  hr = impl->d3D12Device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                            impl->commandAllocator, nullptr,
                                            IID_PPV_ARGS(&impl->commandList));
  if (FAILED(hr))
    return nullptr;

  hr = impl->commandList->Close();
  if (FAILED(hr))
    return nullptr;

  // Create Shared Timeline Fences
  hr = impl->d3D12Device->CreateFence(
      0, D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER | D3D12_FENCE_FLAG_SHARED,
      IID_PPV_ARGS(&impl->renderFinishedFence));
  if (FAILED(hr))
    return nullptr;

  hr = impl->d3D12Device->CreateSharedHandle(impl->renderFinishedFence, nullptr,
                                             GENERIC_ALL, nullptr,
                                             &impl->renderFinishedFenceHandle);
  if (FAILED(hr))
    return nullptr;

  hr = impl->d3D12Device->CreateFence(
      0, D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER | D3D12_FENCE_FLAG_SHARED,
      IID_PPV_ARGS(&impl->copyCompletedFence));
  if (FAILED(hr))
    return nullptr;

  hr = impl->d3D12Device->CreateSharedHandle(impl->copyCompletedFence, nullptr,
                                             GENERIC_ALL, nullptr,
                                             &impl->copyCompletedFenceHandle);
  if (FAILED(hr))
    return nullptr;

  // Query window dimensions
  RECT rect;
  GetClientRect(hwnd, &rect);

  IDXGIFactory5 *dxgiFactory;
  hr = CreateDXGIFactory2(0, IID_PPV_ARGS(&dxgiFactory));
  if (FAILED(hr))
    return nullptr;

  // Configure Swapchain Descriptor
  DXGI_SWAP_CHAIN_DESC1 desc = {
      .Width = static_cast<UINT>(rect.right - rect.left),
      .Height = static_cast<UINT>(rect.bottom - rect.top),
      .Format = DXGI_FORMAT_B8G8R8A8_UNORM,
      .Stereo = FALSE,
      .SampleDesc = {.Count = 1, .Quality = 0},
      .BufferUsage =
          DXGI_USAGE_RENDER_TARGET_OUTPUT, // Explicitly target output
      .BufferCount = 2,                    // Double buffered
      .Scaling = DXGI_SCALING_STRETCH,
      .SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
      .AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED,
      .Flags = DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT // Enable CPU
                                                                  // Pacing
  };

  IDXGISwapChain1 *baseSwapChain = nullptr;
  hr = dxgiFactory->CreateSwapChainForComposition(impl->commandQueue, &desc,
                                                  nullptr, &baseSwapChain);
  dxgiFactory->Release();
  if (FAILED(hr))
    return nullptr;

  hr = baseSwapChain->QueryInterface(IID_PPV_ARGS(&impl->swapChain));
  baseSwapChain->Release();
  if (FAILED(hr))
    return nullptr;

  // Extract the CPU pacing handle
  impl->frameLatencyWaitableObject =
      impl->swapChain->GetFrameLatencyWaitableObject();
  impl->swapChain->SetMaximumFrameLatency(2);

  // Initialize DirectComposition
  IDCompositionDesktopDevice *pDesktopDevice = nullptr;
  hr = DCompositionCreateDevice3(nullptr, __uuidof(IDCompositionDesktopDevice),
                                 reinterpret_cast<void **>(&pDesktopDevice));
  if (FAILED(hr))
    return nullptr;

  hr = pDesktopDevice->QueryInterface(IID_PPV_ARGS(&impl->dCompDevice));
  if (FAILED(hr)) {
    pDesktopDevice->Release();
    return nullptr;
  }

  hr =
      pDesktopDevice->CreateTargetForHwnd(hwnd, TRUE, &impl->compositionTarget);
  pDesktopDevice->Release();
  if (FAILED(hr))
    return nullptr;

  hr = impl->dCompDevice->CreateVisual(&impl->visual);
  if (FAILED(hr))
    return nullptr;

  hr = impl->visual->SetContent(impl->swapChain);
  if (FAILED(hr))
    return nullptr;

  hr = impl->compositionTarget->SetRoot(impl->visual);
  if (FAILED(hr))
    return nullptr;

  hr = impl->dCompDevice->Commit();
  if (FAILED(hr))
    return nullptr;

  return (void *)impl;
}

struct ExportedFences
DirectCompositionInterop_getFences(DirectCompositionInterop interop) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)interop;
  struct ExportedFences fences = {
      .renderFinishedFenceHandle = impl->renderFinishedFenceHandle,
      .copyCompletedFenceHandle = impl->copyCompletedFenceHandle,
  };
  return fences;
}

void DirectCompositionInterop_resize(DirectCompositionInterop interop,
                                     int imageCount, HANDLE **images) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)interop;

  // 1. Clean up old resources to unlock swapchain resizing
  if (impl->importedImages) {
    for (int i = 0; i < impl->imageCount; i++) {
      if (impl->importedImages[i]) {
        impl->importedImages[i]->Release();
      }
    }
    free(impl->importedImages);
    impl->importedImages = nullptr;
  }

  // 2. Fetch fresh client dimensions
  RECT rect;
  GetClientRect(impl->hwnd, &rect);
  UINT width = static_cast<UINT>(rect.right - rect.left);
  UINT height = static_cast<UINT>(rect.bottom - rect.top);

  // 3. Mutate Swapchain sizing
  HRESULT hr = impl->swapChain->ResizeBuffers(
      2, width, height, DXGI_FORMAT_B8G8R8A8_UNORM,
      DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT);
  if (FAILED(hr))
    return;

  // 4. Import the newly allocated Vulkan textures
  impl->imageCount = imageCount;
  impl->importedImages =
      (ID3D12Resource **)malloc(sizeof(ID3D12Resource *) * imageCount);
  for (int i = 0; i < imageCount; i++) {
    hr = impl->d3D12Device->OpenSharedHandle(
        images[i], IID_PPV_ARGS(&impl->importedImages[i]));
  }
}

void DirectCompositionInterop_waitForImage(DirectCompositionInterop interop,
                                           int frameIndex) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)interop;

  // 1. Sleep CPU until DXGI/DWM has structural room for a new frame submission
  WaitForSingleObjectEx(impl->frameLatencyWaitableObject, INFINITE, TRUE);

  // 2. Safety Pacing for Single Allocator reuse:
  // If we loop back around, verify the GPU is entirely done with the last frame
  // that used this allocator.
  uint64_t targetClearValue =
      static_cast<uint64_t>(frameIndex) - impl->imageCount;
  if (frameIndex >= impl->imageCount &&
      impl->copyCompletedFence->GetCompletedValue() < targetClearValue) {
    HANDLE event = CreateEventEx(nullptr, nullptr, 0, EVENT_ALL_ACCESS);
    impl->copyCompletedFence->SetEventOnCompletion(targetClearValue, event);
    WaitForSingleObject(event, INFINITE);
    CloseHandle(event);
  }
}

void DirectCompositionInterop_present(DirectCompositionInterop interop,
                                      int frameIndex) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)interop;

  int imageIndex = frameIndex % impl->imageCount;
  UINT backBufferIndex = impl->swapChain->GetCurrentBackBufferIndex();

  ID3D12Resource *dxgiBackbuffer = nullptr;
  HRESULT hr = impl->swapChain->GetBuffer(backBufferIndex,
                                          IID_PPV_ARGS(&dxgiBackbuffer));
  if (FAILED(hr))
    return;

  ID3D12Resource *srcImage = impl->importedImages[imageIndex];

  // 1. Enqueue GPU wait condition: Halt D3D12 execution until Vulkan finishes
  // writing
  impl->commandQueue->Wait(impl->renderFinishedFence, frameIndex);

  // 2. Record copying procedures
  impl->commandAllocator->Reset();
  impl->commandList->Reset(impl->commandAllocator, nullptr);

  // Transition DXGI backbuffer to destination layout
  D3D12_RESOURCE_BARRIER barriers[2] = {};
  barriers[0].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  barriers[0].Transition.pResource = dxgiBackbuffer;
  barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
  barriers[0].Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST;
  barriers[0].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

  // Transition shared texture to source layout
  barriers[1].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  barriers[1].Transition.pResource = srcImage;
  barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_COMMON;
  barriers[1].Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
  barriers[1].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

  impl->commandList->ResourceBarrier(2, barriers);

  // Execute VRAM Blit
  impl->commandList->CopyResource(dxgiBackbuffer, srcImage);

  // Revert resource layouts back to original states
  barriers[0].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
  barriers[0].Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;

  barriers[1].Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_SOURCE;
  barriers[1].Transition.StateAfter = D3D12_RESOURCE_STATE_COMMON;

  impl->commandList->ResourceBarrier(2, barriers);
  impl->commandList->Close();

  // 3. Dispatch Copy Lists to engine queue
  ID3D12CommandList *lists[] = {impl->commandList};
  impl->commandQueue->ExecuteCommandLists(1, lists);

  // 4. Enqueue GPU Signal condition: Notify Vulkan that memory copying is
  // finished
  impl->commandQueue->Signal(impl->copyCompletedFence, frameIndex);

  // 5. Blit context execution completion to desktop presentation engine
  impl->swapChain->Present(1, 0);

  // Clean up contextual handle frame reference
  dxgiBackbuffer->Release();
}

void DirectCompositionInterop_destroy(DirectCompositionInterop interop) {
  if (!interop)
    return;
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)interop;

  if (impl->importedImages) {
    for (int i = 0; i < impl->imageCount; i++) {
      if (impl->importedImages[i])
        impl->importedImages[i]->Release();
    }
    free(impl->importedImages);
  }

  if (impl->commandList)
    impl->commandList->Release();
  if (impl->commandAllocator)
    impl->commandAllocator->Release();
  if (impl->commandQueue)
    impl->commandQueue->Release();
  if (impl->renderFinishedFence)
    impl->renderFinishedFence->Release();
  if (impl->copyCompletedFence)
    impl->copyCompletedFence->Release();
  if (impl->visual)
    impl->visual->Release();
  if (impl->compositionTarget)
    impl->compositionTarget->Release();
  if (impl->dCompDevice)
    impl->dCompDevice->Release();
  if (impl->swapChain)
    impl->swapChain->Release();
  if (impl->d3D12Device)
    impl->d3D12Device->Release();

  if (impl->renderFinishedFenceHandle)
    CloseHandle(impl->renderFinishedFenceHandle);
  if (impl->copyCompletedFenceHandle)
    CloseHandle(impl->copyCompletedFenceHandle);

  free(impl);
}

}
