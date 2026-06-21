import types;
import sdf_shapes;

static const uint STACK_SIZE = 16;

[[vk::push_constant]]
uniform ConstantBuffer<float4x4> viewMatrix;

[[vk::binding(0, 0)]]
uniform StructuredBuffer<RenderNode> renderNodeData;

[[vk::binding(1, 0)]]
uniform StructuredBuffer<ShapeMergingEntry> shapeGroupData;

[[vk::binding(2, 0)]]
uniform StructuredBuffer<DrawListItem> drawList;

// this is per node
struct DrawListItem {
  uint32_t index;
  DrawMode drawMode;  
};

enum DrawMode: uint32_t {
  Fill = 0,
  Stroke = 1,
  Shadow = 2,
};

[[vk::binding(0, 1)]]
uniform Texture2D[] textures;

// global fr
[[vk::binding(0, 2)]]
uniform SamplerState sampler;


struct VertexInput {
  uint32_t instanceIndex : SV_InstanceID;
  uint32_t vertexIndex : SV_VertexID;
};

struct VertexOutput {
  nointerpolation uint32_t renderNodeDataIndex;
  float4 sv_position : SV_Position;
  float2 localPosition;
  DrawMode drawMode;
};

static const float2 g_Positions[6] = {
  float2(-1.0, -1.0),
  float2(1.0, -1.0),
  float2(1.0, 1.0),
  float2(1.0, 1.0),
  float2(-1.0, 1.0),
  float2(-1.0, -1.0),
};

[shader("vertex")]
VertexOutput vsMain(VertexInput input) {
  VertexOutput output;
  let item = drawList[input.instanceIndex];
  output.renderNodeDataIndex = item.index;
  output.drawMode = item.drawMode;

  let renderNode = renderNodeData[item.index];
  
  let expand: float = item.drawMode == DrawMode.Shadow ? (renderNode.shadowSpread + renderNode.shadowBlur * 2) : 0;

  float2 pos;
  switch (input.vertexIndex) {
  case 0:
  case 5:
    pos = float2(renderNode.boundMinX, renderNode.boundMinY) - expand;
    break;
  case 1:
    pos = float2(renderNode.boundMaxX + expand, renderNode.boundMinY - expand);
    break;
  case 2:
  case 3:
    pos = float2(renderNode.boundMaxX, renderNode.boundMaxY) + expand;
    break;
  default: // case 4
    pos = float2(renderNode.boundMinX - expand, renderNode.boundMaxY + expand);
    break;
  }


  output.localPosition = pos;
  output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(pos, 0.0, 1.0)));
  return output;
}

[[shader("fragment")]]
float4 fsMain(VertexOutput input): SV_Target {
  let renderNode = renderNodeData[input.renderNodeDataIndex];
  let position = input.localPosition;

  switch (input.drawMode) {
    case DrawMode.Fill:
      return computeFill(renderNode, position);
    case DrawMode.Stroke:
      return computeBorder(renderNode, position);
    case DrawMode.Shadow:
      return computeShadow(renderNode, position);
  }

  return float4(0.0);
}

float4 computeBorder(RenderNode renderNode, float2 position) {
  var d = sdfDistance(renderNode, position);
  var color = float4(0.0, 0.0, 0.0, 0.0);

  // TODO: correction term when merging
  if (renderNode.borderBrushKind == BrushKind.solid) {
    var brush = bit_cast<SolidColorBrush>(renderNode.borderBrushData0);
    color = brush.color;
  } else if (renderNode.borderBrushKind == BrushKind.texture) {
    var brush = unpackTextureBrush(renderNode.borderBrushData0, renderNode.borderBrushData1, renderNode.borderBrushData2, renderNode.borderBrushData3);
    color = textures[brush.textureIndex].Sample(sampler, textureLocalPositionOf(position, brush));
    // premultiply
    color.xyz *= color.w;
  }
  
  if (d < -(renderNode.borderWidth / 2)) {
    d = -d - renderNode.borderWidth;
  }
  
  return color * smoothCoverageOf(d);
}

float4 computeShadow(RenderNode renderNode, float2 position) {
  let d = sdfDistance(renderNode, position + float2(renderNode.shadowOffsetX, renderNode.shadowOffsetY)) - renderNode.shadowSpread;
  let color = renderNode.shadowColor;
  let progress = clamp(1 - d / (renderNode.shadowBlur * 2), 0, 1);

  return color * renderNode.shadowOpacity * pow(progress, 4);
}


float4 computeFill(RenderNode renderNode, float2 position) {
  let d = sdfDistance(renderNode, position) + renderNode.borderWidth / 2;
  var color = float4(0.0, 0.0, 0.0, 0.0);

  if (renderNode.brushKind == BrushKind.solid) {
    var brush = bit_cast<SolidColorBrush>(renderNode.brushData0);
    color = brush.color;
  } else if (renderNode.brushKind == BrushKind.texture) {
    var brush = unpackTextureBrush(renderNode.brushData0, renderNode.brushData1, renderNode.brushData2, renderNode.brushData3);
    color = textures[brush.textureIndex].Sample(sampler, textureLocalPositionOf(position, brush));
    // premultiply
    color.xyz *= color.w;
  }
  
  return color * smoothCoverageOf(d);
}

float2 textureLocalPositionOf(float2 position, TextureBrush brush) {
  let scaled = position * float2(brush.tileScaleX, brush.tileScaleY) + float2(0.5, 0.5);

  // TODO: repeat stuff, and

  // its clamped to edge
  let cropped = clamp(scaled, float2(brush.cropLeft, brush.cropTop), float2(brush.cropLeft + brush.cropWidth, brush.cropTop + brush.cropHeight));

  return cropped;
}

float sdfDistance(RenderNode renderNode, float2 position) {
  switch (renderNode.oneOrManyKind) {
  case OneOrManyShapeKind.one_shape:
    return sdf(position, renderNode.shapeKind, renderNode.shapeData);
  case OneOrManyShapeKind.many_shapes:
    let shapeGroup = renderNode.shapeData;
    uint startIndex = shapeGroup.x;
    uint count = shapeGroup.y;

    return sdfMerge(position, startIndex, count);
  }
  return 0;
}

float sdfMerge(float2 position, uint startIndex, uint count) {
    // merge stack
  uint top = 0;
  float[STACK_SIZE] stack;
  for (uint i = 0u; i < count; i++) {
    ShapeMergingEntry entry = shapeGroupData[startIndex + i];
    if (entry.kind == ShapeMergingInstructionKind.push) {
      stack[top] = sdf(position - entry.offset, bit_cast<ShapeKind>(entry.mergeMode_or_shapeKind), entry.data);
      top += 1;
    } else {
      // merge
      let mergeMode = bit_cast<MergeMode>(entry.mergeMode_or_shapeKind);
      let k = bit_cast<float>(entry.data0); // smoothing stored as float bits
      let a = stack[top - 1]; // top = last pushed
      let b = stack[top - 2]; // second = first pushed
      float result = b;
      switch (mergeMode) {
      case MergeMode.union_:
        result = k <= 0 ? min(a, b) : sdfSmoothUnion(a, b, k);
        break;
      case MergeMode.intersect:
        result = k <= 0 ? max(a, b) : sdfSmoothIntersect(a, b, k);
        break;
      case MergeMode.subtract:
        // b - a: b=first pushed (base), a=top (shape to remove)
        result = k <= 0 ? max(b, -a) : sdfSmoothSubtract(b, a, k);
        break;
      default: // xor_
        result = max(min(a, b), -max(a, b));
        break;
      }
      stack[top - 2] = result;
      top -= 1;
    }
  }

  return stack[0];
}

float sdf(float2 position, ShapeKind kind, uint4 data) {
  float distance = 0;
  switch (kind) {
  case ShapeKind.rect:
    var rect = bit_cast<Rect>(data);
    return sdfRoundRect(position, float2(rect.width, rect.height), rect.cornerRadius, rect.cornerDegree);
  case ShapeKind.arc:
    var arc = bit_cast<Arc>(data.xyz);
    return sdfArc(position, arc.radius, arc.angle, arc.thickness);
  case ShapeKind.pie:
    var pie = bit_cast<Pie>(data.xyz);
    return sdfPie(position, pie.radius, pie.angle, pie.perimeterOffset);
  case ShapeKind.ellipse:
    var ellipse = bit_cast<Ellipse>(data.xy);
    return sdfEllipse(position, float2(ellipse.radiusX, ellipse.radiusY));
  }

  return distance;
}

float smoothCoverageOf(float distance) {
  float edgeWidth = 0.5;
  return smoothstep(edgeWidth, -edgeWidth, distance);
}

// bias is for shadow
float2 getShapeBound(uint corner, ShapeKind kind, uint4 data, float bias = 0.0) {
  float2 half;
  switch (kind) {
  case ShapeKind.rect:
    // sdfRoundRect divides by 2 internally, so half-extent is width/2, height/2
    var rect = bit_cast<Rect>(data);
    half = float2(rect.width, rect.height) * 0.5 + bias;
    break;
  case ShapeKind.arc:
    var arc = bit_cast<Arc>(data.xyz);
    let arcOuter = arc.radius + arc.thickness * 0.5 + bias;
    half = float2(arcOuter, arcOuter);
    break;
  case ShapeKind.pie:
    var pie = bit_cast<Pie>(data.xyz);
    let pieR = pie.radius + max(pie.perimeterOffset, 0.0) + bias;
    half = float2(pieR, pieR);
    break;
  case ShapeKind.ellipse:
    var ellipse = bit_cast<Ellipse>(data.xy);
    half = float2(ellipse.radiusX, ellipse.radiusY) + bias;
    break;
  default:
    return float2(0.0);
  }

  switch (corner) {
  case 0:
  case 5:
    return -half;
  case 1:
    return float2(half.x, -half.y);
  case 2:
  case 3:
    return half;
  default: // case 4
    return float2(-half.x, half.y);
  }
}
