#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(location = 0) in vec4 inSizing;
layout(location = 1) in uvec4 inTextureData;
layout(location = 2) in vec2 inPosition;

layout(location = 0) out vec4 outSizing;
layout(location = 1) flat out uvec4 outTextureData;

void main() {
    outSizing = inSizing;
    outTextureData = inTextureData;

    gl_Position = vec4(inPosition, 0, 1);
}