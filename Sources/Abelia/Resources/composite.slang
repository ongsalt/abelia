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

  switch (renderNode.oneOrManyKind) {
  case OneOrManyShapeKind.one_shape:
    let pos = getShapeBound(input.vertexIndex, renderNode.shapeKind, renderNode.shapeData);
    output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(pos, 0.0, 1.0)));
    break;
  case OneOrManyShapeKind.many_shapes:
    let shapeGroup = renderNode.shapeData;
    uint startIndex = shapeGroup.x;
    uint count = shapeGroup.y;

    // merge
    ShapeMergingEntry first = shapeGroupData[startIndex];
    float2 position = getShapeBound(input.vertexIndex, bit_cast<ShapeKind>(first.mergeMode_or_shapeKind), first.data) + first.offset;
    for (uint i = 1; i < count; i++) {
      ShapeMergingEntry entry = shapeGroupData[startIndex + i];
      if (entry.kind == ShapeMergingInstructionKind.push) {
        let corner = getShapeBound(input.vertexIndex, bit_cast<ShapeKind>(entry.mergeMode_or_shapeKind), entry.data) + entry.offset;

        switch (input.vertexIndex) {
        case 0:
        case 5:
          position = min(position, corner);
          break;
        case 1:
          position.x = max(position.x, corner.x);
          position.y = min(position.y, corner.y);
          break;
        case 2:
        case 3:
          position = max(position, corner);
          break;
        case 4:
          position.x = min(position.x, corner.x);
          position.y = max(position.y, corner.y);
          break;
        }
      }
    }

    output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(position, 0.0, 1.0)));
  }

  return output;
}

[[shader("fragment")]]
float4 fsMain(VertexOutput input) {
  let renderNode = renderNodeData[input.renderNodeDataIndex];
  let position = input.sv_position.xy - renderNode.affine[3].xy;

  var color = float4(1.0, 0.0, 0.0, 0.2);
  float coverage = 0.0;

  if (renderNode.brushKind == BrushKind.solid) {
    var brush = bit_cast<SolidColorBrush>(renderNode.brushData);
    color = brush.color;
  }

  switch (renderNode.oneOrManyKind) {
  case OneOrManyShapeKind.one_shape:
    var distance = sdf(position, renderNode.shapeKind, renderNode.shapeData);

    if (distance < 0) {
      coverage = 1;
    }
    break;
  case OneOrManyShapeKind.many_shapes:
    let shapeGroup = renderNode.shapeData;
    uint startIndex = shapeGroup.x;
    uint count = shapeGroup.y;

    // merge stack
    uint topIndex = 0;
    float[STACK_SIZE] stack;
    for (uint i = 0u; i < count; i++) {
      ShapeMergingEntry entry = shapeGroupData[startIndex + i];
      if (entry.kind == ShapeMergingInstructionKind.push) {
        stack[topIndex] = sdf(position - entry.offset, bit_cast<ShapeKind>(entry.mergeMode_or_shapeKind), entry.data);
        topIndex += 1;
      } else {
        // merge
        let mergeMode = bit_cast<MergeMode>(entry.mergeMode_or_shapeKind);
        switch (mergeMode) { // in this case data.x
        case MergeMode.union_:
          let a = stack[topIndex - 1];
          let b = stack[topIndex - 2];
          stack[topIndex - 2] = sdfSmoothUnion(a, b, entry.data.x); // entry.data.x = smoothing
          topIndex -= 1;
        }
      }
    }

    if (stack[0] < 0) {
      coverage = 1;
    }
  }

  return color * coverage;
}

float sdf(float2 position, ShapeKind kind, uint4 data) {
  switch (kind) {
  case ShapeKind.rect:
    var rect = bit_cast<Rect>(data);
    return sdfRoundRect(position, float2(rect.width, rect.height), rect.cornerRadius, rect.cornerDegree);
  }

  return 0.0;
}

// bias is for shadow
float2 getShapeBound(uint corner, ShapeKind kind, uint4 data, float bias = 0.0) {
  switch (kind) {
  case ShapeKind.rect:
    var rect = bit_cast<Rect>(data);
    switch (corner) {
    case 0:
    case 5:
      return float2(-rect.width, -rect.height);
    case 1:
      return float2(rect.width, -rect.height);
    case 2:
    case 3:
      return float2(rect.width, rect.height);
    case 4:
      return float2(-rect.width, rect.height);
    }
  }

  return float2(0.0);
}
