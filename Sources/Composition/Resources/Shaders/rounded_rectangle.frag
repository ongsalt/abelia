#version 450

#extension GL_EXT_buffer_reference : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

layout(set = 0, binding = 10) uniform sampler2D globalTextures[];

layout(location = 0) in vec4 inColor;
layout(location = 1) in vec4 inSizing; // (cx,cy,w,h)
layout(location = 2) in vec4 borderRadiusAndRotation;
layout(location = 3) in vec4 borderWidthAndDegree;

layout(location = 4) in vec4 inBorderColor;
layout(location = 5) in uint inTextureIndex;
layout(location = 6) in vec4 inShadowParams; // (offsetX, offsetY, blur, mode)
layout(location = 7) in vec2 inScreenSize;

layout(location = 9) in vec4 inTransformC1;
layout(location = 10) in vec4 inTransformC2;
layout(location = 11) in vec4 inTransformC3;
layout(location = 12) in vec4 inTransformC4;

// layout(location = 9) in vec4 c1;
// layout(location = 10) in vec4 c2;
// layout(location = 11) in vec4 c3;
// layout(location = 12) in vec4 c4;


layout(location = 0) out vec4 outFragColor;

float sdRoundedRectSuperellipse(vec2 p, vec2 halfBox, float radius, float degree) {
    vec2 q = abs(p) - halfBox + radius;
    float inD = min(max(q.x, q.y), 0.0);
    vec2 mq = max(q, 0.0);
    float n = max(degree, 1.0);
    float outD = pow(pow(mq.x, n) + pow(mq.y, n), 1.0 / n) - radius;
    return inD + outD;
}

// Abramowitz-Stegun erf approximation (max error ~1.5e-7)
float erfApprox(float x) {
    float sign = x < 0.0 ? -1.0 : 1.0;
    x = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * x);
    float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t) * exp(-x * x);
    return sign * y;
}

void main() {
    mat4 transform = mat4(inTransformC1, inTransformC2, inTransformC3, inTransformC4);
    vec2 localPos = (transform * vec4(gl_FragCoord.xy, 0.0, 1.0)).xy;
    vec2 localCenter = (transform * vec4(inSizing.xy, 0.0, 1.0)).xy;
    vec2 p = localPos - localCenter;

    vec2 box = inSizing.zw / 2;
    float d = sdRoundedRectSuperellipse(p, box, borderRadiusAndRotation.x, borderWidthAndDegree.y);

    float borderWidth = borderWidthAndDegree.x;

    float mode = inShadowParams.w;

    // 0 = normal
    // 1 = shadow
    // 2 = texture
    if (mode > 1.5) {

    }

    // mode 1
    if (mode > 0.5) {
        float shadowAlpha = 0.0;
        if (inColor.a > 0.0 && inShadowParams.z > 0.0) {
            vec2 ps = p - inShadowParams.xy;
            float ds = sdRoundedRectSuperellipse(ps, box, borderRadiusAndRotation.x, borderWidthAndDegree.y);
            float outside = max(ds, 0.0);
            float t = outside / max(inShadowParams.z, 1e-4);
            shadowAlpha = 1.0 - (0.5 + 0.5 * erfApprox(t * 1.41421356));
        }
        outFragColor = inColor * shadowAlpha;
        return;
    }

    // mode 0
    vec4 shape = vec4(0.0);
    if (d <= 0.0) {
        if (borderWidth > 0.0 && d > -borderWidth) {
            shape = inBorderColor;
        } else {
            shape = inColor;
        }
    }

    outFragColor = shape;
}