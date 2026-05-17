[[vk::push_constant]]
uniform ConstantBuffer<float2> viewportSize;

[[vk::binding(0, 0)]]
uniform SamplerState sampler;

[[vk::binding(1, 0)]]
uniform StructuredBuffer<LayerStorageNode> layoutStorageNodes;

[[vk::binding(0, 1)]]
uniform Texture2D[] textures;

struct VertexInput {
  uint32_t layoutNodeIndex;
  float2 position;
};

struct VertexOutput {
  nointerpolation uint32_t layoutNodeIndex;
  float4 sv_position : SV_Position;
};

[shader("vertex")]
VertexOutput vertMain(VertexInput input) {
  VertexOutput output;
  output.layoutNodeIndex = input.layoutNodeIndex;
  output.sv_position = float4((input.position / (viewportSize / 2)) - 1, 0.0, 1.0);
  return output;
}

[shader("fragment")]
float4 fragMain(VertexOutput inVert, float4 position: SV_Position) : SV_Target {
  let layoutStorageNode = layoutStorageNodes[inVert.layoutNodeIndex];

  // if (inVert.layoutNodeIndex == 0) {
  //   return float4(1, 1, 0, 1);
  // }

  // return float4(0.1, 0.1, 0.1, 0.1);
  // return float4(0.1, 0.1, inVert.layoutNodeIndex * 0.1, 0.1);

  if (layoutStorageNode.brushKind == BrushKind.Solid) {
    let solidColorBrush = unpackSolidColorBrush(layoutStorageNode.brush);
    return solidColorBrush.color;
  } else if (layoutStorageNode.brushKind == BrushKind.Texture) {
    let textureBrush = unpackTextureBrush(layoutStorageNode.brush);
    let texture = textures[textureBrush.textureIndex];

    let rect = unpackRoundedRect(layoutStorageNode.shape);

    let origin = layoutStorageNode.center - float2(rect.halfWidth, rect.halfHeight);
    let relativePosition = (position.xy - origin) / (2 * float2(rect.halfWidth, rect.halfHeight));
    return texture.Sample(sampler, 1 - relativePosition);
  }

  // let texture = layoutStorageNode;
  // let c = texture.Sample(sampler, position.xy / 500);

  return float4(0.1, 0.1, 0.1, 1); // fallback color
}

// MARKER: TYPES

// ==========================================
// Enums
// ==========================================

enum ShapeKind : uint {
  RoundRect = 0,
};

enum BrushKind : uint {
  Solid = 0,
  Gradient1D = 1,
  Texture = 2,
};

// ==========================================
// Shape Definitions & Union
// ==========================================

struct RoundedRect {
  float halfWidth;
  float halfHeight;
  float cornerRadius;
  float cornerDegree;
};

// Represents the `union Shape` from C.
// Sized to the largest shape (RoundedRect: 16 bytes)
struct ShapeUnion {
  float4 payload;
};

// ==========================================
// Brush Definitions & Union
// ==========================================

struct SolidColorBrush {
  float4 color;
};

struct TextureBrush {
  uint textureIndex;
  float4 ninegrid;
  float4 crop;
};

// Represents the `union Brush` from C.
// Sized to the largest brush (TextureBrush: 36 bytes -> 9 uints)
struct BrushUnion {
  uint payload[9];
};

// ==========================================
// Main Layer Node
// ==========================================

struct LayerStorageNode {
  // 16-byte aligned types
  float4x4 affine;
  float4 shadowColor;
  ShapeUnion shape;

  // 8-byte aligned types
  float2 center;
  float2 shadowOffset;

  // 4-byte aligned types
  BrushUnion brush;
  float opacity;
  float shadowBlur;
  ShapeKind shapeKind;
  BrushKind brushKind;

  // Slang will invisibly add 12 bytes of padding right here
  // to bring the final struct size to 176 bytes.
};

// ==========================================
// Conversion (Unpack) Functions
// ==========================================

RoundedRect unpackRoundedRect(ShapeUnion buffer) {
  RoundedRect shape;
  shape.halfWidth = buffer.payload.x;
  shape.halfHeight = buffer.payload.y;
  shape.cornerRadius = buffer.payload.z;
  shape.cornerDegree = buffer.payload.w;
  return shape;
}

SolidColorBrush unpackSolidColorBrush(BrushUnion buffer) {
  SolidColorBrush brush;

  brush.color = asfloat(uint4(
      buffer.payload[0],
      buffer.payload[1],
      buffer.payload[2],
      buffer.payload[3]));

  return brush;
}

TextureBrush unpackTextureBrush(BrushUnion buffer) {
  TextureBrush brush;

  // First element is natively a uint
  brush.textureIndex = buffer.payload[0];

  // Unpack ninegrid (elements 1-4)
  brush.ninegrid = asfloat(uint4(
      buffer.payload[1],
      buffer.payload[2],
      buffer.payload[3],
      buffer.payload[4]));

  // Unpack crop (elements 5-8)
  brush.crop = asfloat(uint4(
      buffer.payload[5],
      buffer.payload[6],
      buffer.payload[7],
      buffer.payload[8]));

  return brush;
}
