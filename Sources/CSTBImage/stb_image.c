#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include "stbi_extras.h"
#include <stdio.h>

#ifdef _WIN32
#  include <io.h>
#  define stbi__fdopen(fd, mode) _fdopen(fd, mode)
#else
#  define stbi__fdopen(fd, mode) fdopen(fd, mode)
#endif

stbi_uc* stbi_load_from_fd(int fd, int* x, int* y, int* channels_in_file, int desired_channels) {
    FILE* f = stbi__fdopen(fd, "rb");
    if (!f) return NULL;
    stbi_uc* result = stbi_load_from_file(f, x, y, channels_in_file, desired_channels);
    fclose(f);
    return result;
}
