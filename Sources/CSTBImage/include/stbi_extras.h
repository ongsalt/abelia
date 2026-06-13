#pragma once
#include "stb_image.h"

// Load from a POSIX file descriptor. Closes fd after loading.
STBIDEF stbi_uc* stbi_load_from_fd(int fd, int* x, int* y, int* channels_in_file, int desired_channels);
