#include <iostream>
#include <utility>
#ifdef _WIN32

#include "d3d12_presenter.hpp"

#include "wil.h"
#include <cstdint>
#include <handleapi.h>
#include <synchapi.h>

namespace {

D3D12_RESOURCE_BARRIER Transition(ID3D12Resource *res,
                                  D3D12_RESOURCE_STATES before,
                                  D3D12_RESOURCE_STATES after) {
  D3D12_RESOURCE_BARRIER b{};
  b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  b.Transition.pResource = res;
  b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
  b.Transition.StateBefore = before;
  b.Transition.StateAfter = after;
  return b;
}

} // namespace

D3D12Presenter::D3D12Presenter(uint32_t width, uint32_t height, HWND hwnd,
                               uint32_t image_count)
    : width_(width), height_(height), hwnd_(hwnd), image_count_(image_count) {
  CreateDeviceAndSwapChain();
  CreateSharedTexture();
  CreateSharedFence();
  CreateCompositionTarget();
}

void D3D12Presenter::CreateDeviceAndSwapChain() {
  UINT factoryFlags = 0;
#ifdef _DEBUG
  wil::com_ptr<ID3D12Debug> debug;
  if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(debug.put())))) {
    debug->EnableDebugLayer();
    factoryFlags = DXGI_CREATE_FACTORY_DEBUG;
  }
#endif
  wil::com_ptr<IDXGIFactory7> factory;
  THROW_IF_FAILED(
      CreateDXGIFactory2(factoryFlags, IID_PPV_ARGS(factory.put())));

  THROW_IF_FAILED(D3D12CreateDevice(nullptr, D3D_FEATURE_LEVEL_11_0,
                                    IID_PPV_ARGS(device_.put())));
  luid_ = device_->GetAdapterLuid();

  D3D12_COMMAND_QUEUE_DESC qd{};
  qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  THROW_IF_FAILED(device_->CreateCommandQueue(&qd, IID_PPV_ARGS(queue_.put())));

  DXGI_SWAP_CHAIN_DESC1 scd{};
  scd.Width = width_;
  scd.Height = height_;
  scd.Format = DXGI_FORMAT_B8G8R8A8_UNORM; // required for DComp alpha
  scd.SampleDesc = {1, 0};
  scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  scd.BufferCount = image_count_ + 1;
  scd.Scaling = DXGI_SCALING_STRETCH;
  scd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  scd.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;
  scd.Flags = DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT;

  wil::com_ptr<IDXGISwapChain1> sc1;
  THROW_IF_FAILED(factory->CreateSwapChainForComposition(queue_.get(), &scd,
                                                         nullptr, sc1.put()));
  swapChain_ = sc1.query<IDXGISwapChain3>();

  backBuffers_.clear();
  for (uint32_t i = 0; i < image_count_ + 1; ++i) {
    wil::com_ptr<ID3D12Resource> ptr;
    THROW_IF_FAILED(swapChain_->GetBuffer(i, IID_PPV_ARGS(ptr.put())));
    backBuffers_.push_back(ptr);

    wil::com_ptr<ID3D12CommandAllocator> allocator;
    wil::com_ptr<ID3D12GraphicsCommandList> commandList;
    THROW_IF_FAILED(device_->CreateCommandAllocator(
        D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(allocator.put())));
    THROW_IF_FAILED(device_->CreateCommandList(
        0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator.get(), nullptr,
        IID_PPV_ARGS(commandList.put())));
    THROW_IF_FAILED(commandList->Close()); // start closed; Present() resets it

    allocators_.push_back(allocator);
    commandLists_.push_back(commandList);
  }

  THROW_IF_FAILED(swapChain_->SetMaximumFrameLatency(image_count_));
  _waitable.reset(swapChain_->GetFrameLatencyWaitableObject());
}

void D3D12Presenter::CreateSharedTexture() {
  D3D12_HEAP_PROPERTIES heap{};
  heap.Type = D3D12_HEAP_TYPE_DEFAULT;

  D3D12_RESOURCE_DESC rd{};
  rd.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
  rd.Width = width_;
  rd.Height = height_;
  rd.DepthOrArraySize = 1;
  rd.MipLevels = 1;
  // sRGB typed: Vulkan renders sRGB-encoded bytes into it
  // (VK_FORMAT_B8G8R8A8_SRGB). The copy into the UNORM backbuffer stays inside
  // the B8G8R8A8 typeless family, so it is a raw bit copy -- which is what DWM
  // expects to be handed.
  rd.Format = DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
  rd.SampleDesc = {1, 0};
  rd.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
  rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;

  // SHARED heap + COMMON initial state are required to share cross-API.
  for (uint32_t i = 0; i < image_count_; i++) {
    wil::com_ptr<ID3D12Resource> sharedTexture;
    THROW_IF_FAILED(device_->CreateCommittedResource(
        &heap, D3D12_HEAP_FLAG_SHARED, &rd, D3D12_RESOURCE_STATE_COMMON,
        nullptr, IID_PPV_ARGS(sharedTexture.put())));
    sharedTextures_.push_back(sharedTexture);

    HANDLE h = nullptr;
    THROW_IF_FAILED(device_->CreateSharedHandle(sharedTexture.get(), nullptr,
                                                GENERIC_ALL, nullptr, &h));
    sharedTextureHandles_.push_back(h);
  }
}

void D3D12Presenter::ReleaseSharedTextures() {
  // Vulkan holds its own reference to the underlying resource once the handle
  // has been imported, so closing here does not pull the memory out from under
  // it.
  for (auto handle : sharedTextureHandles_) {
    CloseHandle(handle);
  }
  sharedTextureHandles_.clear();
  sharedTextures_.clear();
}

D3D12Presenter::~D3D12Presenter() { ReleaseSharedTextures(); }

void D3D12Presenter::CreateSharedFence() {
  THROW_IF_FAILED(device_->CreateFence(0, D3D12_FENCE_FLAG_SHARED,
                                       IID_PPV_ARGS(fence_.put())));
  HANDLE h = nullptr;
  THROW_IF_FAILED(device_->CreateSharedHandle(fence_.get(), nullptr,
                                              GENERIC_ALL, nullptr, &h));
  sharedFenceHandle_.reset(h);
  fenceEvent_.create();
}

D3D12Images D3D12Presenter::Images() {
  D3D12Images images = {
      .width = width_,
      .height = height_,
      .image_count = image_count_,
  };

  if (image_count_ >= 1) {
    images.image1 = sharedTextureHandles_[0];
  }

  if (image_count_ >= 2) {
    images.image2 = sharedTextureHandles_[1];
  }

  if (image_count_ >= 3) {
    images.image3 = sharedTextureHandles_[2];
  }

  return images;
}

HANDLE D3D12Presenter::Fence() { return sharedFenceHandle_.get(); }

void D3D12Presenter::Wait() {
  WaitForSingleObjectEx(_waitable.get(), 1000, true);
}

void D3D12Presenter::Present(uint32_t imageIndex, uint64_t renderDoneValue,
                             uint64_t copyDoneValue) {
  // Queue waits until Vulkan has finished rendering into the shared texture.
  THROW_IF_FAILED(queue_->Wait(fence_.get(), renderDoneValue));

  const uint32_t index = swapChain_->GetCurrentBackBufferIndex();
  ID3D12Resource *back = backBuffers_[index].get();

  auto commandList = commandLists_[index];
  auto allocator = allocators_[index];

  THROW_IF_FAILED(allocator->Reset());
  THROW_IF_FAILED(commandList->Reset(allocator.get(), nullptr));

  auto toCopyDest = Transition(back, D3D12_RESOURCE_STATE_PRESENT,
                               D3D12_RESOURCE_STATE_COPY_DEST);
  commandList->ResourceBarrier(1, &toCopyDest);

  // sharedTex_ sits in COMMON and is promoted to COPY_SOURCE implicitly.
  commandList->CopyResource(back, sharedTextures_[imageIndex].get());

  auto toPresent = Transition(back, D3D12_RESOURCE_STATE_COPY_DEST,
                              D3D12_RESOURCE_STATE_PRESENT);
  commandList->ResourceBarrier(1, &toPresent);
  THROW_IF_FAILED(commandList->Close());

  ID3D12CommandList *lists[] = {commandList.get()};
  queue_->ExecuteCommandLists(1, lists);

  // Tell Vulkan the copy is done so it may render into the texture again.
  THROW_IF_FAILED(queue_->Signal(fence_.get(), copyDoneValue));
  THROW_IF_FAILED(swapChain_->Present(1, 0));
}

void D3D12Presenter::CreateCompositionTarget() {
  THROW_IF_FAILED(DCompositionCreateDevice3(
      nullptr, IID_PPV_ARGS(composition_device_.put())));
  THROW_IF_FAILED(
      composition_device_->CreateTargetForHwnd(hwnd_, TRUE, target_.put()));

  wil::com_ptr<IDCompositionDevice3> compositor =
      composition_device_.query<IDCompositionDevice3>();
  wil::com_ptr<IDCompositionVisual2> visual;
  THROW_IF_FAILED(compositor->CreateVisual(visual.put()));
  visual_ = visual.query<IDCompositionVisual3>();

  // wil::com_ptr<IDCompositionGaussianBlurEffect> effect;
  // THROW_IF_FAILED(compositor->CreateGaussianBlurEffect(effect.put()));
  // THROW_IF_FAILED(effect->SetStandardDeviation(15));
  // THROW_IF_FAILED(visual_->SetEffect(effect.get()));

  THROW_IF_FAILED(visual_->SetContent(swapChain_.get()));
  THROW_IF_FAILED(target_->SetRoot(visual_.get()));
  THROW_IF_FAILED(composition_device_->Commit());
}

void D3D12Presenter::WaitFence(uint64_t value) {
  if (value == 0 || fence_->GetCompletedValue() >= value) {
    return;
  }
  THROW_IF_FAILED(fence_->SetEventOnCompletion(value, fenceEvent_.get()));
  fenceEvent_.wait();
}

void D3D12Presenter::RetireSharedTextures() {
  // for (auto handle : sharedTextureHandles_) {
  //   CloseHandle(handle);
  // }
  // sharedTextureHandles_.clear();
  // sharedTextures_.clear();

  for (auto s : sharedTextureHandles_) {
    retiredSharedTextureHandles_.push_back(s);
  }

  for (auto t : sharedTextures_) {
    retiredSharedTextures_.push_back(t);
  }
}

void D3D12Presenter::Resize(uint32_t width, uint32_t height,
                            uint64_t currentFenceValue) {
  // wait until all rendering + copying are done
  // stutter a bit
  WaitFence(currentFenceValue);

  width_ = width;
  height_ = height;

  // release all ref to backbuffer, must clear NOW
  backBuffers_.clear();

  // release all fif image in next N frames?
  // actually need to retire PER SLOT, cuz we want to present the already drawn
  // image or we discard its present?
  ReleaseSharedTextures();

  THROW_IF_FAILED(swapChain_->ResizeBuffers(
      0, width, height, DXGI_FORMAT_UNKNOWN,
      DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT));

  // recreate it
  for (uint32_t i = 0; i < image_count_ + 1; ++i) {
    wil::com_ptr<ID3D12Resource> buffer;
    THROW_IF_FAILED(swapChain_->GetBuffer(i, IID_PPV_ARGS(buffer.put())));
    backBuffers_.push_back(buffer);
  }
  CreateSharedTexture();
}
#endif