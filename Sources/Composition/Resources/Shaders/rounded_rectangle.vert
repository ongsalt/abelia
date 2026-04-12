#version 450

#extension GL_EXT_buffer_reference : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

layout(buffer_reference, std430) buffer UniformBufferObject {
    float w;
    float h;
};

layout(push_constant) uniform PushConstants {
    UniformBufferObject ubo; // This is strictly an 8-byte pointer
} pc;


layout(location = 0) in vec4 inColor;
layout(location = 1) in vec4 inSizing; // (cx,cy,w,h)
layout(location = 2) in vec4 borderRadiusAndRotation;
layout(location = 3) in vec4 borderWidthAndDegree;

layout(location = 4) in vec4 inBorderColor;
layout(location = 5) in uint inTextureIndex;
layout(location = 6) in vec4 inShadowParams; // (offsetX, offsetY, blur, mode)
layout(location = 7) in vec2 inVertexPosition;

layout(location = 9) in vec4 inTransformC1;
layout(location = 10) in vec4 inTransformC2;
layout(location = 11) in vec4 inTransformC3;
layout(location = 12) in vec4 inTransformC4;


layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outSizing; // (cx,cy,w,h)
layout(location = 2) out vec4 outBorderRadiusAndRotation;
layout(location = 3) out vec4 outBorderWidthAndDegree;

layout(location = 4) out vec4 outBorderColor;
layout(location = 5) out uint outTextureIndex;
layout(location = 6) out vec4 outShadowParams;
layout(location = 7) out vec2 outScreenSize;

layout(location = 9) out vec4 outTransformC1;
layout(location = 10) out vec4 outTransformC2;
layout(location = 11) out vec4 outTransformC3;
layout(location = 12) out vec4 outTransformC4;



void main() {
    outSizing = inSizing;
    outBorderRadiusAndRotation = borderRadiusAndRotation;
    outBorderWidthAndDegree = borderWidthAndDegree;
    outBorderColor = inBorderColor;
    outShadowParams = inShadowParams;
    outScreenSize = vec2(pc.ubo.w, pc.ubo.h);
    outTransformC1 = inTransformC1;
    outTransformC2 = inTransformC2;
    outTransformC3 = inTransformC3;
    outTransformC4 = inTransformC4;
    outTextureIndex = inTextureIndex;
    
    vec2 scaled_pos = (inVertexPosition / vec2(pc.ubo.w, pc.ubo.h)) * 2.0 - 1.0;

    gl_Position = vec4(scaled_pos, 0.0, 1.0);
    outColor = inColor;

}