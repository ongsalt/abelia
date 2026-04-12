#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(push_constant) uniform PushConstants {
    uvec2 screenSize;
} pc;

layout(location = 0) in vec4 inSizing;
layout(location = 1) in uvec4 inTextureData;
layout(location = 2) in vec2 inPosition;

layout(location = 0) flat out vec4 outSizing;
layout(location = 1) flat out uvec4 outTextureData;
layout(location = 2) out vec2 outUV;

void main() {
    outSizing = inSizing;
    outTextureData = inTextureData;

    gl_Position = vec4(inPosition / pc.screenSize * 2, 0, 1);
    outUV = (inPosition.xy - inSizing.xy) / inSizing.zw;
}