#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef void* DirectCompositionInterop;

struct ExportedFences {
  _Nonnull HANDLE renderFinishedFenceHandle;
  _Nonnull HANDLE copyCompletedFenceHandle;
};

DirectCompositionInterop  createDirectCompositionInterop(_Nonnull HWND hwnd, int imageCount);

struct ExportedFences DirectCompositionInterop_getFences(DirectCompositionInterop interop);

void DirectCompositionInterop_resize(DirectCompositionInterop interop, int imageCount, HANDLE** images);

void DirectCompositionInterop_waitForImage(DirectCompositionInterop interop,
                                            int frameIndex);

void DirectCompositionInterop_present(DirectCompositionInterop interop,
                                          int frameIndex);

void DirectCompositionInterop_destroy(DirectCompositionInterop interop);
