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
  scd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
  scd.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;
  scd.Flags = DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT;

  wil::com_ptr<IDXGISwapChain1> sc1;
  THROW_IF_FAILED(factory->CreateSwapChainForComposition(queue_.get(), &scd,
                                                         nullptr, sc1.put()));
  swapChain_ = sc1.query<IDXGISwapChain3>();

  for (uint32_t i = 0; i < image_count_ + 1; ++i)
    THROW_IF_FAILED(
        swapChain_->GetBuffer(i, IID_PPV_ARGS(backBuffers_[i].put())));

  THROW_IF_FAILED(device_->CreateCommandAllocator(
      D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(allocator_.put())));
  THROW_IF_FAILED(device_->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                             allocator_.get(), nullptr,
                                             IID_PPV_ARGS(cmdList_.put())));
  THROW_IF_FAILED(cmdList_->Close()); // start closed; Present() resets it

  THROW_IF_FAILED(swapChain_->SetMaximumFrameLatency(1));
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
  rd.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  rd.SampleDesc = {1, 0};
  rd.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
  rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;

  // SHARED heap + COMMON initial state are required to share cross-API.
  for (int i = 0; i < image_count_; i++) {
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

  THROW_IF_FAILED(allocator_->Reset());
  THROW_IF_FAILED(cmdList_->Reset(allocator_.get(), nullptr));

  auto toCopyDest = Transition(back, D3D12_RESOURCE_STATE_PRESENT,
                               D3D12_RESOURCE_STATE_COPY_DEST);
  cmdList_->ResourceBarrier(1, &toCopyDest);

  // sharedTex_ sits in COMMON and is promoted to COPY_SOURCE implicitly.
  cmdList_->CopyResource(back, sharedTextures_[imageIndex].get());

  auto toPresent = Transition(back, D3D12_RESOURCE_STATE_COPY_DEST,
                              D3D12_RESOURCE_STATE_PRESENT);
  cmdList_->ResourceBarrier(1, &toPresent);
  THROW_IF_FAILED(cmdList_->Close());

  ID3D12CommandList *lists[] = {cmdList_.get()};
  queue_->ExecuteCommandLists(1, lists);

  // Tell Vulkan the copy is done so it may render into the texture again.
  THROW_IF_FAILED(queue_->Signal(fence_.get(), copyDoneValue));
  THROW_IF_FAILED(swapChain_->Present(1, 0));

  // // Bound latency: block until this frame's copy has retired.
  // if (fence_->GetCompletedValue() < copyDoneValue) {
  //   THROW_IF_FAILED(
  //       fence_->SetEventOnCompletion(copyDoneValue, fenceEvent_.get()));
  //   fenceEvent_.wait();
  // }
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

  wil::com_ptr<IDCompositionGaussianBlurEffect> effect;
  THROW_IF_FAILED(compositor->CreateGaussianBlurEffect(effect.put()));
  THROW_IF_FAILED(effect->SetStandardDeviation(5));
  // THROW_IF_FAILED(visual_->SetEffect(effect.get()));

  THROW_IF_FAILED(visual_->SetContent(swapChain_.get()));
  THROW_IF_FAILED(target_->SetRoot(visual_.get()));
  THROW_IF_FAILED(composition_device_->Commit());
}

void D3D12Presenter::Resize(uint32_t width, uint32_t height,
                            uint64_t currentFenceValue) {
  // wait until all rendering are done
  if (fence_->GetCompletedValue() < currentFenceValue) {
    THROW_IF_FAILED(
        fence_->SetEventOnCompletion(currentFenceValue, fenceEvent_.get()));
    fenceEvent_.wait();
  }

  // release all ref to backbuffer
  backBuffers_.clear();

  // release all fif image
  for (auto handle : sharedTextureHandles_) {
    CloseHandle(handle);
  }
  sharedTextures_.clear();

  swapChain_->ResizeBuffers1(0, width, height, DXGI_FORMAT_B8G8R8A8_UNORM,
                             DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT,
                             nullptr, nullptr);

  // recreate it
  for (uint32_t i = 0; i < image_count_ + 1; ++i)
    THROW_IF_FAILED(
        swapChain_->GetBuffer(i, IID_PPV_ARGS(backBuffers_[i].put())));
  CreateSharedTexture();
}