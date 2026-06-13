import types;
import sdf_shapes;

static const uint STACK_SIZE = 16;

[[vk::push_constant]]
uniform ConstantBuffer<float4x4> viewMatrix;

[[vk::binding(0, 0)]]
uniform StructuredBuffer<RenderNode> renderNodeData;

[[vk_binding(1, 0)]]
uniform StructuredBuffer<ShapeMergingEntry> shapeGroupData;

[[vk_binding(2, 0)]]
uniform StructuredBuffer<uint32_t> drawList;

struct VertexInput {
  uint32_t instanceIndex : SV_InstanceID;
  uint32_t vertexIndex : SV_VertexID;
};

struct VertexOutput {
  nointerpolation uint32_t renderNodeDataIndex;
  float4 sv_position : SV_Position;
  float2 localPosition;
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
  let renderNodeDataIndex = drawList[input.instanceIndex];
  output.renderNodeDataIndex = renderNodeDataIndex;

  let renderNode = renderNodeData[renderNodeDataIndex];

  if (renderNode.oneOrManyKind == OneOrManyShapeKind.one_shape) {
    let pos = getShapeBound(input.vertexIndex, renderNode.shapeKind, renderNode.shapeData);
    output.localPosition = pos;
    output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(pos, 0.0, 1.0)));
  } else {
    let shapeGroup = renderNode.shapeData;
    uint startIndex = shapeGroup.x;
    uint count = shapeGroup.y;

    // First entry is always a push — use it to seed the AABB
    ShapeMergingEntry first = shapeGroupData[startIndex];
    let firstKind = bit_cast<ShapeKind>(first.mergeMode_or_shapeKind);
    float2 boundsMin = getShapeBound(0, firstKind, first.data) + first.offset;
    float2 boundsMax = getShapeBound(2, firstKind, first.data) + first.offset;

    // Expand AABB with remaining push entries
    for (uint i = 1; i < count; i++) {
      ShapeMergingEntry entry = shapeGroupData[startIndex + i];
      if (entry.kind == ShapeMergingInstructionKind.push) {
        let shapeKind = bit_cast<ShapeKind>(entry.mergeMode_or_shapeKind);
        boundsMin = min(boundsMin, getShapeBound(0, shapeKind, entry.data) + entry.offset);
        boundsMax = max(boundsMax, getShapeBound(2, shapeKind, entry.data) + entry.offset);
      }
    }

    float2 pos;
    switch (input.vertexIndex) {
    case 0:
    case 5:
      pos = boundsMin;
      break;
    case 1:
      pos = float2(boundsMax.x, boundsMin.y);
      break;
    case 2:
    case 3:
      pos = boundsMax;
      break;
    default: // case 4
      pos = float2(boundsMin.x, boundsMax.y);
      break;
    }

    output.localPosition = pos;
    output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(pos, 0.0, 1.0)));
  }

  return output;
}

[[shader("fragment")]]
float4 fsMain(VertexOutput input): SV_Target {
  let renderNode = renderNodeData[input.renderNodeDataIndex];
  let position = input.localPosition;

  var color = float4(0.0);
  float coverage = 0.0;

  // return float4(input.localPosition, 1.0, 0.5);

  if (renderNode.brushKind == BrushKind.solid) {
    var brush = bit_cast<SolidColorBrush>(renderNode.brushData);
    color = brush.color;
  }

  switch (renderNode.oneOrManyKind) {
  case OneOrManyShapeKind.one_shape:
    coverage = smoothCoverageOf(sdf(position, renderNode.shapeKind, renderNode.shapeData));
    break;
  case OneOrManyShapeKind.many_shapes:
    let shapeGroup = renderNode.shapeData;
    uint startIndex = shapeGroup.x;
    uint count = shapeGroup.y;

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

    coverage = smoothCoverageOf(stack[0]);
  }

  // TODO: fix this, when doing 3d transform, smoothCoverageOf dont work

  color.w *= coverage;
  return color;
}

float sdf(float2 position, ShapeKind kind, uint4 data) {
  float distance = 0;
  switch (kind) {
  case ShapeKind.rect:
    var rect = bit_cast<Rect>(data);
    return sdfRoundRect(position, float2(rect.width, rect.height), rect.cornerRadius, rect.cornerDegree);
  case ShapeKind.ellipse:
    var ellipse = bit_cast<Ellipse>(data.xy);
    return sdfEllipse(position, float2(ellipse.radiusX, ellipse.radiusY));
  }

  return distance;
}

float smoothCoverageOf(float distance) {
  float edgeWidth = fwidth(distance);
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
