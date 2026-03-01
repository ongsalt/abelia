#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(set = 0, binding = 0) uniform sampler2D renderTextures[];

layout(location = 0) in vec4 inSizing;
layout(location = 1) flat in uvec4 inTextureData;

layout(location = 0) out vec4 outFragColor;

void main() {
    vec2 position = inSizing.xy - gl_FragCoord.xy;
    // outFragColor = texture(renderTextures[inTextureData.x], position);
    outFragColor = vec4(0.2, 1.0, 0.0, 0.5);
}
