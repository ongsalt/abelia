#include <stdint.h>

struct VertexData {
  uint32_t layoutNodeIndex;
  float positionX;
  float positionY;
};

// TODO: wait what if its kawase blur
enum __attribute__((enum_extensibility(closed))) EffectKind: uint32_t {
  blurX,
  blurY,
  colorMatrix,
};

struct BlurEffect {
  float radius;
};

struct ColorMatrixEffect {
  float data[20];
};

union _Effect {
  struct BlurEffect blur;
  struct ColorMatrixEffect colorMatrix;
};

struct EffectVertexData {
  enum EffectKind effectKind;
  union _Effect effect;
  float positionX;
  float positionY;
};