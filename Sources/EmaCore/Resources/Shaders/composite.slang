[[vk::push_constant]]
ConstantBuffer<float2> viewportSize;

[[vk::binding(0, 0)]]
Sampler2D sampler;

[[vk::binding(0, 1)]]
Texture2DArray textures;

struct VertexInput {
  uint32_t layoutNodeIndex;
  float2 position;
};

struct VertexOutput {
  float3 color;
  float4 sv_position : SV_Position;
};

[shader("vertex")]
VertexOutput vertMain(VertexInput input) {
  VertexOutput output;
  output.sv_position = float4(input.position, 0.0, 1.0);
  output.color = float3(1.0, 1.0, 0.5);
  return output;
}

[shader("fragment")]
float4 fragMain(VertexOutput inVert) : SV_Target {
  float3 color = inVert.color;
  return float4(color, 1.0);
}
