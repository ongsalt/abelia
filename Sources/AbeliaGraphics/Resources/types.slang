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

public enum TextureFillMode : uint {
  stretch = 0,
  tile = 1,
};

public struct SolidColorBrush {
  public float4 color;  // 16 bytes
};

// Layout matches C TextureBrush exactly (56 bytes).
public struct TextureBrush {
  public uint textureIndex;
  public uint fillMode;     // TextureFillMode
  public float tileScaleX;
  public float tileScaleY;
  public float cropLeft;
  public float cropTop;
  public float cropWidth;
  public float cropHeight;
  public float sliceLeft;
  public float sliceTop;
  public float sliceWidth;
  public float sliceHeight;
  public float2 size;       // physical pixel size of the rendered region
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
// unused???
public struct ShapeMergingInstruction {
  public uint mergeMode_or_shapeKind;
  public uint4 data;    // merge: data.x = smoothing bits; push: full shape union (16 bytes)
  public float2 offset; // push only
};

// Packed kind + data — use this as the StructuredBuffer element type.
// Layout: kind(4) + mergeMode_or_shapeKind(4) + data(16) + offset(8) = 32 bytes
// Uses scalar fields only: std430 gives uint4 16-byte alignment which would
// add 8 bytes of padding after mergeMode_or_shapeKind, mismatching the C layout.
public struct ShapeMergingEntry {
  public ShapeMergingInstructionKind kind;
  public uint mergeMode_or_shapeKind;
  public uint data0;
  public uint data1;
  public uint data2;
  public uint data3;
  public float offsetX;
  public float offsetY;

  public property uint4 data { get { return uint4(data0, data1, data2, data3); } }
  public property float2 offset { get { return float2(offsetX, offsetY); } }
};

public TextureBrush unpackTextureBrush(uint4 d0, uint4 d1, uint4 d2, uint4 d3) {
  TextureBrush b;
  b.textureIndex = d0.x;
  b.fillMode     = d0.y;
  b.tileScaleX   = asfloat(d0.z);
  b.tileScaleY   = asfloat(d0.w);
  b.cropLeft     = asfloat(d1.x);
  b.cropTop      = asfloat(d1.y);
  b.cropWidth    = asfloat(d1.z);
  b.cropHeight   = asfloat(d1.w);
  b.sliceLeft    = asfloat(d2.x);
  b.sliceTop     = asfloat(d2.y);
  b.sliceWidth   = asfloat(d2.z);
  b.sliceHeight  = asfloat(d2.w);
  b.size         = float2(asfloat(d3.x), asfloat(d3.y));
  return b;
}

// Matches C struct RenderNode exactly.
// Layout: affine(64) + shapeData(16) + brushData(64) + oneOrManyKind(4) + shapeKind(4) + brushKind(4) + _pad(4) = 160 bytes
public struct RenderNode {
  public float4x4 affine;

  // one_shape:   raw Shape union bits (bit_cast to Rect/Arc/Pie/Ellipse)
  // many_shapes: .x = startIndex, .y = count into ShapeMergingInstruction buffer
  public uint4 shapeData;

  // raw Brush union (64 bytes) split into four uint4 chunks.
  // solid:   bit_cast<SolidColorBrush>(brushData0)
  // texture: bit_cast<TextureBrush>(brushData0, brushData1, brushData2, brushData3[0..1])
  public uint4 brushData0;
  public uint4 brushData1;
  public uint4 brushData2;
  public uint4 brushData3;

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
