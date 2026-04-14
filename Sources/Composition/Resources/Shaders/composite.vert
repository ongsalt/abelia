#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(push_constant) uniform PushConstants {
    uvec2 screenSize;
} pc;

layout(set = 0, binding = 0) uniform sampler2D renderTextures[];

layout(location = 0) in vec4 inOpacityScreenSizeAndMode;
layout(location = 1) in vec4 inSizing; // position.{x,y}, size.{w,h}

layout(location = 2) in vec4 inTransformC1;
layout(location = 3) in vec4 inTransformC2;
layout(location = 4) in vec4 inTransformC3;
layout(location = 5) in vec4 inTransformC4;

layout(location = 6) in vec4 inCornerRadius;
layout(location = 7) in vec4 inCornerDegreeAndBorderWidthAndVertexPos; // 2 float left
layout(location = 8) in vec4 inColor;
layout(location = 9) in vec4 inBorderColor;
layout(location = 10) in vec4 inTintColor;
layout(location = 11) in vec4 inShadow; // offset (why tho), blur, spread (why)

layout(location = 12) in uvec4 inContents; // hasContent, contentIndex
layout(location = 13) in vec4 inNineGrid; // normalized??? (uv coord)


layout(location = 0) flat out vec4 outOpacityScreenSizeAndMode;
layout(location = 1) flat out vec4 outSizing;

// layout(location = 2) out vec4 outTransformC1;
// layout(location = 3) out vec4 outTransformC2;
// layout(location = 4) out vec4 outTransformC3;
// layout(location = 5) out vec4 outTransformC4;

layout(location = 6) out vec4 outCornerRadius;
layout(location = 7) out vec4 outCornerDegreeAndBorderWidthAndVertexPos;
layout(location = 8) out vec4 outColor;
layout(location = 9) out vec4 outBorderColor;
layout(location = 10) out vec4 outTintColor;
layout(location = 11) out vec4 outShadow; // TODO: normalized this from the cpu

layout(location = 12) flat out uvec4 outContents;
layout(location = 13) out vec4 outNineGrid;
layout(location = 14) out vec2 outRelativeOffset;


void main() {
    outOpacityScreenSizeAndMode = inOpacityScreenSizeAndMode;
    outSizing = inSizing;

    // outTransformC1 = inTransformC1;
    // outTransformC2 = inTransformC2;
    // outTransformC3 = inTransformC3;
    // outTransformC4 = inTransformC4;

    outCornerRadius = inCornerRadius;
    outCornerDegreeAndBorderWidthAndVertexPos = inCornerDegreeAndBorderWidthAndVertexPos;
    outColor = inColor;
    outBorderColor = inBorderColor;
    outTintColor = inTintColor;
    outShadow = inShadow;

    outContents = inContents;
    outNineGrid = inNineGrid;

    vec2 vertexPos = outCornerDegreeAndBorderWidthAndVertexPos.zw;
    vec2 scaled_pos = (vertexPos / vec2(inOpacityScreenSizeAndMode.y, inOpacityScreenSizeAndMode.z)) * 2.0 - 1.0;
    gl_Position = vec4(scaled_pos, 0.0, 1.0);

    mat4 transform = mat4(inTransformC1, inTransformC2, inTransformC3, inTransformC4);
    vec2 localPos = (transform * vec4(vertexPos, 0.0, 1.0)).xy;
    vec2 localCenter = (transform * vec4((inSizing.xy + inSizing.zw / 2.0), 0.0, 1.0)).xy;
    outRelativeOffset = localPos - localCenter;
}
