module types;

public enum ShapeKind : uint {
  rect = 0,
  arc = 1,
  pie = 2,
  // polygon = 3,
  ellipse = 4,
};

public struct Rect {
  public float width;
  public float height;
  public float cornerRadius;
  public float cornerDegree;
};

public struct Arc {
  public float radius;
  public float angle;
  public float thickness;
};

public struct Pie {
  public float radius;
  public float angle;
  public float perimeterOffset;
};

public struct Ellipse {
  public float radiusX;
  public float radiusY;
};

public enum OneOrManyShapeKind : uint {
  one_shape = 0,
  many_shapes = 1,
};

public enum BrushKind : uint {
  solid = 0,
  gradient1d = 1,
  texture = 2
};

public struct SolidColorBrush {
  public float4 color;
};

public enum MergeMode : uint {
  union_ = 0,
  intersect = 1,
  xor_ = 2,
  subtract = 3
};

public struct ShapeMetadata {
  public ShapeKind shapeKind;
  public uint4 shape;   // raw Shape union data (bit_cast to Rect/Arc/Pie/Ellipse)
  public float2 offset;
};

public struct MergeNode {
  public MergeMode mode;
  public float smoothing;
};

public enum ShapeMergingInstructionKind : uint {
  push = 0,
  merge = 1,
};

// Matches C union ShapeMergingInstruction (28 bytes, size of larger member ShapeMetadata).
// When kind == merge: mergeMode_or_shapeKind is MergeMode, bit_cast<float>(data.x) is smoothing.
// When kind == push:  mergeMode_or_shapeKind is ShapeKind, data is shape union raw bits, offset is offset.
public struct ShapeMergingInstruction {
  public uint mergeMode_or_shapeKind;
  public uint4 data;    // merge: data.x = smoothing bits; push: full shape union (16 bytes)
  public float2 offset; // push only
};

// Matches C struct RenderNode exactly.
// Layout: affine(64) + shapeData(16) + brushData(16) + oneOrManyKind(4) + shapeKind(4) + brushKind(4) + _pad(4) = 112 bytes
public struct RenderNode {
  public float4x4 affine;

  // one_shape:   raw Shape union bits (bit_cast to Rect/Arc/Pie/Ellipse)
  // many_shapes: .x = startIndex, .y = count into ShapeMergingInstruction buffer
  public uint4 shapeData;

  public uint4 brushData;   // raw Brush union — bit_cast to SolidColorBrush/etc.

  public OneOrManyShapeKind oneOrManyKind;
  public ShapeKind shapeKind;   // valid when one_shape
  public BrushKind brushKind;
  public uint _pad;
};

// Example of how to extract data from a RenderNode:
// Rect myRect = bit_cast<Rect>(node.shapeData);
// SolidColorBrush myBrush = bit_cast<SolidColorBrush>(node.brushData);
// uint startIndex = node.shapeData.x; // many_shapes only
// uint count      = node.shapeData.y; // many_shapes only
