#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(push_constant) uniform PushConstants {
    uvec2 screenSize;
} pc;

layout(set = 0, binding = 0) uniform sampler2D renderTextures[];

layout(location = 0) flat in vec4 inSizing;
layout(location = 1) flat in uvec4 inTextureData;
layout(location = 2) in vec2 inUV;

layout(location = 0) out vec4 outFragColor;

void main() {
    // vec2 position = (gl_FragCoord.xy - inSizing.xy) / inSizing.zw;
    float opacity = texture(renderTextures[nonuniformEXT(inTextureData.x)], inUV).x;
    outFragColor = vec4(1, 1, 1, 1) * opacity + vec4(0, 0, 0, 0.4) * (1 - opacity);
    // outFragColor = vec4(1, 1, 1, 1) * opacity;
    // outFragColor = vec4(inUV, 0, 1);
}
