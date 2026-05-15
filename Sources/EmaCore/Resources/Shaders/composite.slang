[[vk::push_constant]]
uniform ConstantBuffer<float2> viewportSize;

[[vk::binding(0, 0)]]
uniform SamplerState sampler;

[[vk::binding(0, 1)]]
uniform Texture2D[] textures;

struct VertexInput {
  uint32_t layoutNodeIndex;
  float2 position;
};

struct VertexOutput {
  uint32_t layoutNodeIndex;
  float3 color;
  float4 sv_position : SV_Position;
};

[shader("vertex")]
VertexOutput vertMain(VertexInput input) {
  VertexOutput output;
  output.layoutNodeIndex = input.layoutNodeIndex;
  output.sv_position = float4((input.position / (viewportSize / 2)) - 1, 0.0, 1.0);
  output.color = float3(0.1, 0.1, 0.1);
  return output;
}

[shader("fragment")]
float4 fragMain(VertexOutput inVert, float4 position: SV_Position) : SV_Target {
  float3 color = inVert.color;
  let texture = textures[inVert.layoutNodeIndex];

  let c = texture.Sample(sampler, position.xy / 500);
  
  // this is NOT what layoutNode mean but well
  return max(float4(color, 1.0), c);
}
