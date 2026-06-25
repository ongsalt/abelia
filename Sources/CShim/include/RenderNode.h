#include <stdint.h>

enum __attribute__((enum_extensibility(closed))) ShapeKind : uint32_t {
  rect = 0,
  arc = 1,
  pie = 2,
  // polygon = 3,
  ellipse = 4,
};

struct Rect {
  float width;
  float height;
  float cornerRadius;
  float cornerDegree;
};

struct Arc {
  float radius;
  float angle;
  float thickness;
};

struct Pie {
  float radius;
  float angle;
  float perimeterOffset;
};

struct Ellipse {
  float radiusX;
  float radiusY;
};

union Shape {
  struct Rect rect;
  struct Arc arc;
  struct Pie pie;
  struct Ellipse ellipse;
};

enum __attribute__((enum_extensibility(closed))) OneOrManyShapeKind : uint32_t {
  one_shape = 0,
  many_shapes = 1,
};

struct ManyShapeRef {
  uint32_t startIndex;
  uint32_t count;
};

// Discriminated by OneOrManyShapeKind.
// one_shape:  .one holds the shape's geometric data
// many_shapes: .many holds startIndex + count into the ShapeMergingInstruction buffer
union OneOrManyShapeData {
  union Shape one;
  struct ManyShapeRef many;
};

enum __attribute__((enum_extensibility(closed))) BrushKind : uint32_t {
  solid = 0,
  gradient1d = 1,
  texture = 2
};

enum __attribute__((enum_extensibility(closed))) TextureFillMode : uint32_t {
  tex_stretch = 0,
  tex_tile = 1,
  tex_absolute = 2,
};

struct SolidColorBrush {
  float color[4];       // 16 bytes
};

// Layout: textureIndex(4) + fillMode(4) + tileScale(8) + crop(16) + nineSlices(16) + size(8) = 56 bytes
struct TextureBrush {
  uint32_t textureIndex;  // index into bound texture descriptor array
  uint32_t fillMode;      // TextureFillMode
  float tileScaleX;
  float tileScaleY;
  // normalized UV sub-region to sample
  float cropLeft;
  float cropTop;
  float cropWidth;
  float cropHeight;
  // normalized nine-slice insets
  float sliceLeft;
  float sliceTop;
  float sliceWidth;
  float sliceHeight;
  // physical pixel size of the rendered region (for UV scaling)
  float sizeX;
  float sizeY;
};

union Brush {
  struct SolidColorBrush solid;
  struct TextureBrush texture;
  uint32_t _pad[16]; // union size = 64 bytes to match GPU layout (4 × uint4)
};

// Matches RenderNode in types.slang exactly.
// Layout: affine(64) + shapeData(16) + brushData(64) + oneOrManyKind(4) + shapeKind(4) + brushKind(4) + borderWidth(4)
//       + shadowOffsetX(4) + shadowOffsetY(4) + shadowBlur(4) + shadowSpread(4)
//       + shadowColor(16) + shadowOpacity(4) + borderBrushKind(4) + _pad(8) + borderBrushData(64)
//       + boundMin(8) + boundMax(8) = 288 bytes
struct RenderNode {
  float affine[16];

  union OneOrManyShapeData shapeData;
  union Brush brushData;

  enum OneOrManyShapeKind oneOrManyKind;
  enum ShapeKind shapeKind;    // valid when oneOrManyKind == one_shape
  enum BrushKind brushKind;
  float borderWidth;

  float shadowOffsetX;
  float shadowOffsetY;
  float shadowBlur;
  float shadowSpread;

  float shadowColorR;
  float shadowColorG;
  float shadowColorB;
  float shadowColorA;

  float shadowOpacity;
  enum BrushKind borderBrushKind;
  uint32_t _pad[2];
  union Brush borderBrushData;

  float boundMinX;
  float boundMinY;
  float boundMaxX;
  float boundMaxY;
};


enum __attribute__((enum_extensibility(closed))) MergeMode : uint32_t {
  _union = 0,
  intersect = 1,
  _xor = 2,
  subtract = 3
};

struct ShapeMetadata {
  enum ShapeKind shapeKind;
  union Shape shape;
  float offset[2];
};

struct MergeNode {
  enum MergeMode mode;
  float smoothing;
};

enum __attribute__((enum_extensibility(closed))) ShapeMergingInstructionKind : uint32_t {
  push = 0,
  merge = 1,
};

union ShapeMergingInstruction {
  struct MergeNode merge;
  struct ShapeMetadata shape;
};

// Packed kind + data for use as a StructuredBuffer element.
// Layout: kind(4) + data(28) = 32 bytes
struct ShapeMergingEntry {
  enum ShapeMergingInstructionKind kind;
  union ShapeMergingInstruction data;
};

enum __attribute__((enum_extensibility(closed))) DrawMode : uint32_t {
  fill = 0,
  stroke = 1,
  shadow = 2,
};

// Layout: index(4) + drawMode(4) = 8 bytes
struct DrawListItem {
  uint32_t index;
  enum DrawMode drawMode;
};
