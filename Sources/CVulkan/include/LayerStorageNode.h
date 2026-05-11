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

// TODO: fixed size struct
struct LayerStorageNode {
  float centerX;
  float centerY;
  float opacity;

  enum ShapeKind shapeKind;
  union Shape shape;

  enum BrushKind brushKind;
  union Brush brush;

  float shadowColor[4];
  float shadowBlur;
  float shadowOffsetX;
  float shadowOffsetY;

  float affine[16];
};
