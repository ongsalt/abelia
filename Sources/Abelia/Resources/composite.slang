import types;
import sdf_shapes;

[[vk::push_constant]]
uniform ConstantBuffer<float2> viewportSize;

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
  float2(-1.0, 1.0),
  float2(1.0, 1.0),
  float2(-1.0, -1.0),  
  float2(1.0, -1.0),
  float2(1.0, 1.0),
};

[shader("vertex")]
VertexOutput vsMain(VertexInput input) {
  VertexOutput output;
  output.renderNodeDataIndex = input.instanceIndex;
  let pos = g_Positions[input.vertexIndex] / 3.0;
  output.sv_position = float4(pos + float2(input.instanceIndex / 12.0), 0.0, 1.0);
  return output;
}

[[shader("fragment")]]
float4 fsMain(VertexOutput input) {
  return float4(0.5, 0.0, float(input.renderNodeDataIndex) / 8.0, 1.0);

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
