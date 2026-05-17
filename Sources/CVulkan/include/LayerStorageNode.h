#include <stdint.h>

enum __attribute__((enum_extensibility(closed))) ShapeKind: uint32_t {
  roundRect = 0,
};

struct RoundedRect {
  float halfWidth;
  float halfHeight;
  float cornerRadius;
  float cornerDegree;
};

union Shape {
  struct RoundedRect roundedRect;
};

enum __attribute__((enum_extensibility(closed))) BrushKind: uint32_t {
  solid = 0,
  gradient1d,
  texture
};

struct SolidColorBrush {
  float color[4];
};

struct TextureBrush {
  uint32_t textureIndex;
  float ninegrid[4];
  float crop[4];
};

union Brush {
  struct SolidColorBrush solid;
  // struct Gradient1DBrush gradient1d;
  struct TextureBrush texture;
};


struct LayerStorageNode {
// --- 16-byte aligned boundary ---
  float affine[16];        // Offset: 0   (Size: 64)
  float shadowColor[4];    // Offset: 64  (Size: 16)
  union Shape shape;       // Offset: 80  (Size: 16)

  // --- 8-byte aligned boundary ---
  float centerX;           // Offset: 96  (Size: 4)
  float centerY;           // Offset: 100 (Size: 4)
  float shadowOffsetX;     // Offset: 104 (Size: 4)
  float shadowOffsetY;     // Offset: 108 (Size: 4)

  // --- 4-byte aligned boundary ---
  union Brush brush;       // Offset: 112 (Size: 36)
  float opacity;           // Offset: 148 (Size: 4)
  float shadowBlur;        // Offset: 152 (Size: 4)
  enum ShapeKind shapeKind;// Offset: 156 (Size: 4)
  enum BrushKind brushKind;// Offset: 160 (Size: 4)

  // TOTAL ACTIVE SIZE: 164 bytes

  // --- Critical Detail: Tail Padding ---
  // Slang requires the total struct size to be a multiple of its 
  // largest alignment (16 bytes). 164 rounds up to 176.
  // If sending an ARRAY of these to the GPU, you MUST add 12 bytes 
  // of tail padding in C so the array strides match.
  uint32_t _pad[3];
};
