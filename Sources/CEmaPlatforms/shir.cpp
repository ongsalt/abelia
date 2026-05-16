#include <cstdint>
#include <iostream>
#include <ostream>

#define WIN32_LEAN_AND_MEAN
#include <d3d12.h>
#include <dcomp.h>
#include <windows.h>
#include <dxgiformat.h>

#include "include/wrapper.h"

struct DirectCompositionInteropImpl {
  ID3D12Device8 *d3D12Device;
  ID3D12CommandAllocator *commandAllocator;
  ID3D12CommandQueue *commandQueue;
  ID3D12GraphicsCommandList *commandList;

  int imageCount;
  ID3D12Resource **importedImages;
  // vulkan need to provide this

  ID3D12Fence *renderFinishedFence;
  ID3D12Fence *copyCompletedFence;
  HANDLE renderFinishedFenceHandle;
  HANDLE copyCompletedFenceHandle;

  IDCompositionDevice3 *dCompDevice;
  IDCompositionTarget *compositionTarget;
  IDCompositionVisual2 *visual;
  IDXGISwapChain1 *swapChain;
};


// DirectCompositionInterop DirectCompositionInterop_create(HWND hwnd) {}
DirectCompositionInterop createDirectCompositionInterop(HWND hwnd,
                                                        int imageCount) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl *)malloc(
      sizeof(DirectCompositionInteropImpl));

  impl->imageCount = imageCount;

  // Create the D3D device object.
  // flag enables rendering on surfaces using Direct2D.
  HRESULT hr = D3D12CreateDevice(nullptr, D3D_FEATURE_LEVEL_12_0,
                                 IID_PPV_ARGS(&impl->d3D12Device));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // Create command queue
  D3D12_COMMAND_QUEUE_DESC commandQueueDesc = {
      .Type = D3D12_COMMAND_LIST_TYPE_DIRECT};
  hr = impl->d3D12Device->CreateCommandQueue(&commandQueueDesc,
                                             IID_PPV_ARGS(&impl->commandQueue));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // Create command allocator
  hr = impl->d3D12Device->CreateCommandAllocator(
      D3D12_COMMAND_LIST_TYPE_COPY, IID_PPV_ARGS(&impl->commandAllocator));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // Create commandList
  hr = impl->d3D12Device->CreateCommandList(
    0,
    D3D12_COMMAND_LIST_TYPE_DIRECT, // D3D12_COMMAND_LIST_TYPE_COPY
    impl->commandAllocator,
    nullptr,
    IID_PPV_ARGS(&impl->commandList)
  );
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }


  hr = impl->commandList->Close();
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }


  // Create fences
  hr = impl->d3D12Device->CreateFence(
      0, D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER | D3D12_FENCE_FLAG_SHARED,
      IID_PPV_ARGS(&impl->renderFinishedFence));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  impl->d3D12Device->CreateSharedHandle(impl->renderFinishedFence, nullptr,
                                        GENERIC_ALL, nullptr,
                                        &impl->renderFinishedFenceHandle);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  hr = impl->d3D12Device->CreateFence(
      0, D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER | D3D12_FENCE_FLAG_SHARED,
      IID_PPV_ARGS(&impl->copyCompletedFence));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  impl->d3D12Device->CreateSharedHandle(impl->copyCompletedFence, nullptr,
                                        GENERIC_ALL, nullptr,
                                        &impl->copyCompletedFenceHandle);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // Create shared images
  // impl->device->CreateResources();

  // query (current) window size
  RECT rect;
  GetWindowRect(hwnd, &rect);

  IDXGIFactory5 *dxgiFactory;
  hr = CreateDXGIFactory2(
      0, // Flags: Use DXGI_CREATE_FACTORY_DEBUG if you want DXGI debug messages
      IID_PPV_ARGS(&dxgiFactory));
  if (!SUCCEEDED(hr)) {
    std::cout << "died1";
    return nullptr;
  }

  // make a swapchain
  DXGI_SWAP_CHAIN_DESC1 desc = {
      .Width = static_cast<UINT>(rect.right - rect.left),
      .Height = static_cast<UINT>(rect.bottom - rect.top),
      .Format = DXGI_FORMAT_B8G8R8A8_UNORM,
      .Stereo = FALSE,
      .SampleDesc = {.Count = 1, .Quality = 0},
      .BufferUsage = 0,
      .BufferCount = 2,
      .Scaling = DXGI_SCALING_STRETCH,
      .SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
      .AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED,
      .Flags = 0};

  hr = dxgiFactory->CreateSwapChainForComposition(impl->commandQueue, &desc,
                                                  nullptr, &impl->swapChain);
  if (!SUCCEEDED(hr)) {
    std::cout << "Failed: " << hr << std::endl;
    return nullptr;
  }

  // MARKER: Composition

  // Create the DirectComposition device object.
  IDCompositionDesktopDevice *pDesktopDevice = nullptr;
  hr = DCompositionCreateDevice3(nullptr, __uuidof(IDCompositionDesktopDevice),
                                 reinterpret_cast<void **>(&pDesktopDevice));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  hr = pDesktopDevice->QueryInterface(IID_PPV_ARGS(&impl->dCompDevice));
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // Create the composition target object based on the
  // specified application window.
  hr =
      pDesktopDevice->CreateTargetForHwnd(hwnd, TRUE, &impl->compositionTarget);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // impl->swapChain->

  // // Create a visual object.
  hr = impl->dCompDevice->CreateVisual(&impl->visual);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // //  we must wait until swapChain creation is finished
  // // impl->swapChain->
  // // hr = impl->visual->SetContent(impl->swapChain);
  // ID2D1DeviceContext *d2DContext;
  // hr = CreateD2DContextFromD3D12(impl->d3D12Device, impl->commandQueue,
  //                                &d2DContext);
  // if (!SUCCEEDED(hr)) {
  //   return nullptr;
  // }

  // IDCompositionSurface *surface;
  // hr =
  //     impl->dCompDevice->CreateSurface(400, 400, DXGI_FORMAT_B8G8R8A8_UNORM,
  //                                      DXGI_ALPHA_MODE_PREMULTIPLIED, &surface);
  // if (!SUCCEEDED(hr)) {
  //   std::cout << hr;
  //   return nullptr;
  // }

  // // ID2D1DeviceContext* d2DContext;
  // hr = CreateSolidColorSurface(impl->dCompDevice, d2DContext, 400, 400,
  //                         D2D1::ColorF(D2D1::ColorF::Red, 0.5f), &surface);
  // if (!SUCCEEDED(hr)) {
  //   return nullptr;
  // }

  hr = impl->visual->SetContent(impl->swapChain);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }


  // Commit the visual to be composed and displayed.
  hr = impl->dCompDevice->Commit();
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  // attach it to target
  hr = impl->compositionTarget->SetRoot(impl->visual);
  if (!SUCCEEDED(hr)) {
    return nullptr;
  }

  return (void *)impl;
}

// also init vulkan then export those image handle into here

struct ExportedFences DirectCompositionInterop_getFences(DirectCompositionInterop interop) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl*) interop;

  struct ExportedFences fences = {
    .renderFinishedFenceHandle = impl->renderFinishedFenceHandle,
    .copyCompletedFenceHandle = impl->copyCompletedFenceHandle,
  };

  return fences;
}

// void DirectCompositionInterop_resize(DirectCompositionInterop interop, int imageCount, HANDLE** images)
void DirectCompositionInterop_resize(DirectCompositionInterop interop, int imageCount, HANDLE** images) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl*) interop;

  // cleanup previous images
  // impl->images
  HRESULT hr;
  
  // reimport images from vulkan
  impl->importedImages = (ID3D12Resource**) malloc(sizeof(ID3D12Resource*) * imageCount);
  for (int i = 0; i < imageCount; i++) {
    hr = impl->d3D12Device->OpenSharedHandle(images[i], IID_PPV_ARGS(&impl->importedImages[i]));
    std::cout << hr << " image " << i << std::endl;
  }

  // tell the swapchain somehow?
}

void DirectCompositionInterop_waitForImage(DirectCompositionInterop interop,
                                            int frameIndex) {
  ///   vulkan cant use that imageIndex until the copy is finished (in waitForImage(frameIndex))
  ///   basically vulkan need to wait copyCompleted[X] on the gpu (not in this file)
  ///   cpu side what do we wait??
}
                                            
void DirectCompositionInterop_present(DirectCompositionInterop interop,
                                          int frameIndex) {
  DirectCompositionInteropImpl *impl = (DirectCompositionInteropImpl*) interop;

  ID3D12Resource *source;

  ///   wait renderFinished[X] + transition to image copy src (signaled by vulkan )
  impl->commandList->Reset(impl->commandAllocator, nullptr);
  impl->commandList->Reset(impl->commandAllocator, nullptr);
  ///   copy to the vkImage to dxgi buffer
  ///   notify copyCompleted[X]
  ///   tell it to present
}

void DirectCompositionInterop_destroy(DirectCompositionInterop interop) {}
