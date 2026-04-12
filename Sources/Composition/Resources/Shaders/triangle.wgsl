const pos = array(
  vec2( 0.0,  0.5),
  vec2(-0.5, -0.5),
  vec2( 0.5, -0.5)
);

const color = array(
  vec3(1., 0., 0.),
  vec3(0., 1., 0.),
  vec3(0., 0., 1.),
);

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) color: vec3f
}

struct FragmentInput {
  @location(0) color: vec3f
}

@vertex
fn vtx_main(@builtin(vertex_index) vertex_index : u32) -> VertexOutput {

  return VertexOutput(vec4(pos[vertex_index], 0, 1.0), color[vertex_index]);
}

@fragment
fn frag_main(input: FragmentInput) -> @location(0) vec4f {
  return vec4(input.color, 1.0);
}
