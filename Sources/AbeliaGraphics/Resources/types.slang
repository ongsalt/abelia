module types;

public enum ShapeKind : uint {
  rect = 0,
  arc = 1,
  pie = 2,
  polygon = 3,
  ellipse = 4,
  pentagon = 5,
  hexagon = 6,
  octagon = 7,
  hexagram = 8,
  pentagram = 9,
  quadraticCircle = 10,
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

// pentagon / hexagon / octagon / hexagram / quadraticCircle: radius is the circumradius
public struct RegularShape {
  public float radius;
};

// pentagram
public struct Star {
  public float radius;
  public float innerRadiusFactor;
};

// arbitrary polygon; vertices live in a dedicated vertex SSBO
public struct Polygon {
  public uint startIndex;
  public uint count;
  public float perimeterOffset;
};


public enum BrushKind : uint {
  solid = 0,
  gradient1d = 1,
  texture = 2
};

public enum TextureFillMode : uint {
  stretch = 0,
  tile = 1,
  absolute = 2,
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
  public uint4 shape;        // raw Shape union data (bit_cast to Rect/Arc/Pie/Ellipse)
  public float4 invLinear;   // inverse 2x2 (invCol0.xy, invCol1.xy): world -> shape-local
  public float2 translation; // forward translation (shape-local -> world)
  public float distanceScale;// shape-local SDF distance -> world units
};

public struct MergeNode {
  public MergeMode mode;
  public float smoothing;
};

// unary op (opRound / opOnion) applied to the top of the merge stack
public enum ModifyMode : uint {
  opRound = 0,
  opOnion = 1,
};

public enum ShapeMergingInstructionKind : uint {
  push = 0,
  merge = 1,
  modify = 2,
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
// Layout: kind(4) + mergeMode_or_shapeKind(4) + data(16) + invLinear(16) + translation(8) + distanceScale(4) = 52 bytes
// Uses scalar fields only: std430 gives vector types 16-byte alignment which would
// insert padding and mismatch the tightly-packed C layout.
public struct ShapeMergingEntry {
  public ShapeMergingInstructionKind kind;
  public uint mergeMode_or_shapeKind;
  public uint data0;
  public uint data1;
  public uint data2;
  public uint data3;
  // push only: inverse 2x2 (world -> shape-local), forward translation, and distance rescale
  public float m00;  // invCol0.x
  public float m01;  // invCol0.y
  public float m10;  // invCol1.x
  public float m11;  // invCol1.y
  public float tx;
  public float ty;
  public float distanceScale;

  public property uint4 data { get { return uint4(data0, data1, data2, data3); } }
  public property float2 invCol0 { get { return float2(m00, m01); } }
  public property float2 invCol1 { get { return float2(m10, m11); } }
  public property float2 translation { get { return float2(tx, ty); } }
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
  b.size         = float2(asfloat(d3.x), asfloat(d3.y)); // reserved
  return b;
}

// Matches C struct RenderNode exactly.
// Layout: affine(64) + shapeStartIndex(4) + shapeCount(4) + _pad_shape(8)
//       + brushData(64) + brushKind(4) + borderBrushKind(4) + borderWidth(4) + opacity(4)
//       + shadowOffsetX(4) + shadowOffsetY(4) + shadowBlur(4) + shadowSpread(4)
//       + shadowColor(16) + shadowOpacity(4) + _pad(12) + borderBrushData(64)
//       + boundMin(8) + boundMax(8) = 288 bytes
public struct RenderNode {
  public float4x4 affine;

  public uint shapeStartIndex;
  public uint shapeCount;
  public uint _pad_shape0;
  public uint _pad_shape1;

  // raw Brush union (64 bytes) split into four uint4 chunks.
  // solid:   bit_cast<SolidColorBrush>(brushData0)
  // texture: bit_cast<TextureBrush>(brushData0, brushData1, brushData2, brushData3[0..1])
  public uint4 brushData0;
  public uint4 brushData1;
  public uint4 brushData2;
  public uint4 brushData3;

  public BrushKind brushKind;
  public BrushKind borderBrushKind;
  public float borderWidth;
  public float opacity;

  public float shadowOffsetX;
  public float shadowOffsetY;
  public float shadowBlur;
  public float shadowSpread;

  public float4 shadowColor;

  public float shadowOpacity;
  public uint _pad0;
  public uint _pad1;
  public uint _pad2;

  // raw border Brush union (64 bytes) split into four uint4 chunks.
  // solid:   bit_cast<SolidColorBrush>(borderBrushData0)
  // texture: bit_cast<TextureBrush>(borderBrushData0..3)
  public uint4 borderBrushData0;
  public uint4 borderBrushData1;
  public uint4 borderBrushData2;
  public uint4 borderBrushData3;

  public float boundMinX;
  public float boundMinY;
  public float boundMaxX;
  public float boundMaxY;
};

// Example of how to extract data from a RenderNode:
// SolidColorBrush myBrush = bit_cast<SolidColorBrush>(node.brushData0);
// uint startIndex = node.shapeStartIndex;
// uint count      = node.shapeCount;
// SolidColorBrush border = bit_cast<SolidColorBrush>(node.borderBrushData0);
// float2 shadowOffset = float2(node.shadowOffsetX, node.shadowOffsetY);
// float2 boundMin = float2(node.boundMinX, node.boundMinY);
// float2 boundMax = float2(node.boundMaxX, node.boundMaxY);


public enum ColorModel: uint {
    DisplayP3 = 0,
    sRGB = 1,
    OKLCH = 2
};

public enum ColorSpace: uint {
    DisplayP3 = 0,
    sRGB = 1,
};
