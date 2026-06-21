import types;

struct ColorStop {
    [[vk::location(0)]] float4 color;
    [[vk::location(1)]] float2 position;
};

struct VertexOutput {
    float4 color;
    float4 position : SV_Position;
};

uniform ColorModel model;
uniform ColorSpace output; // either srgb or p3

[shader("vertex")]
VertexOutput vsMain(ColorStop input) {
    var output = VertexOutput();
    output.color = input.color;
    output.position = float4(input.position, 0.0, 1.0);

    return output;
}


// must output to a linear space, other view can be whatever
[shader("fragment")]
float4 fsMain(VertexOutput input): SV_Target {
    return input.color;
}
