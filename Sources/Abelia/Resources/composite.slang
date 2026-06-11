import types;
import sdf_shapes;

[[vk::push_constant]]
uniform ConstantBuffer<float4x4> viewMatrix;

[[vk::binding(0, 0)]]
uniform StructuredBuffer<RenderNode> renderNodeData;

[[vk_binding(1, 0)]]
uniform StructuredBuffer<ShapeMergingInstructionKind> shapeGroupData;

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
  output.renderNodeDataIndex = input.instanceIndex;

  let renderNode = renderNodeData[input.instanceIndex];
  
  let pos = getShapeBound(input.vertexIndex, renderNode.shapeKind, renderNode.shapeData);
  output.sv_position = mul(viewMatrix, mul(renderNode.affine, float4(pos, 0.0, 1.0)));

  return output;
}

[[shader("fragment")]]
float4 fsMain(VertexOutput input) {
  let renderNode = renderNodeData[input.renderNodeDataIndex];
  let position = mul(renderNode.affine, input.sv_position).xy;

  var color = float4(0.0);
  float coverage = 0.0;

  if (renderNode.brushKind == BrushKind.solid) {
    var brush = bit_cast<SolidColorBrush>(renderNode.brushData);
    color = brush.color;
  }

  var distance = sdf(position, renderNode.shapeKind, renderNode.shapeData);

  if (distance < 0) {
    coverage = 1;
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
