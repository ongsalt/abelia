#version 450

#extension GL_EXT_nonuniform_qualifier : require

layout(push_constant) uniform PushConstants {
    uvec2 screenSize;
} pc;

layout(set = 0, binding = 0) uniform sampler2D renderTextures[];

layout(location = 0) flat in vec4 inOpacityScreenSizeAndMode;
layout(location = 1) flat in vec4 inSizing; // position.{x,y}, size.{w,h}
// this shuold be top left???

// layout(location = 2) in vec4 inTransformC1;
// layout(location = 3) in vec4 inTransformC2;
// layout(location = 4) in vec4 inTransformC3;
// layout(location = 5) in vec4 inTransformC4;

layout(location = 6) in vec4 inCornerRadius;
layout(location = 7) in vec4 inCornerDegreeAndBorderWidthAndVertexPos; // 2 float left
layout(location = 8) in vec4 inColor;
layout(location = 9) in vec4 inBorderColor;
layout(location = 10) in vec4 inTintColor;
layout(location = 11) in vec4 inShadow; // offset (why tho), blur, spread (why)

layout(location = 12) flat in uvec4 inContentsAndMask; // hasContent, contentIndex: u32, hasMask, maskIndex: u32
layout(location = 13) in vec4 inNineGrid; // normalized??? (uv coord)
layout(location = 14) in vec2 inRelativeOffset;



layout(location = 0) out vec4 outFragColor;


// actually sdRoundedBox
float sdRoundedRectSuperellipse(vec2 p, vec2 halfBox, vec4 radius, float degree) {
    radius.xy = (p.x > 0.0) ? radius.xy : radius.zw;
    radius.x  = (p.y > 0.0) ? radius.x  : radius.y;
    
    vec2 q = abs(p) - halfBox + radius.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius.x;
}

// float sdRoundedRectSuperellipse(vec2 p, vec2 halfBox, vec4 radius, float degree) {
//     // radius order: tl, tr, br, bl
//     float selectedRadius;
//     if (p.y > 0.0) {
//         selectedRadius = (p.x > 0.0) ? radius.z : radius.w;
//     } else {
//         selectedRadius = (p.x > 0.0) ? radius.y : radius.x;
//     }

//     vec2 q = abs(p) - halfBox + selectedRadius;
//     float inD = min(max(q.x, q.y), 0.0);
//     vec2 mq = max(q, 0.0);
//     float n = max(degree, 1.0);
//     float outD = pow(pow(mq.x, n) + pow(mq.y, n), 1.0 / n) - selectedRadius;
//     return inD + outD;
// }

// Abramowitz-Stegun erf approximation (max error ~1.5e-7)
float erfApprox(float x) {
    float sign = x < 0.0 ? -1.0 : 1.0;
    x = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * x);
    float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t) * exp(-x * x);
    return sign * y;
}

float sdfCoverage(float d) {
    float aa = max(fwidth(d), 1e-4);
    return clamp(0.5 - d / aa, 0.0, 1.0);
}

float sampledAlpha(vec4 texel) {
    return max(texel.a, texel.r);
}

vec4 over(vec4 foreground, vec4 background) {
    float outA = foreground.a + background.a * (1.0 - foreground.a);
    if (outA <= 1e-5) {
        return vec4(0.0);
    }

    vec3 outRGB = (
        foreground.rgb * foreground.a
        + background.rgb * background.a * (1.0 - foreground.a)
    ) / outA;
    return vec4(outRGB, outA);
}

vec2 contentUVFromRectUV(vec2 rectUV) {
    // inNineGrid: top, left, bottom, right (normalized uv rect)
    bool hasUVRect = (inNineGrid.z > inNineGrid.x) && (inNineGrid.w > inNineGrid.y);
    if (!hasUVRect) {
        return rectUV;
    }

    return vec2(
        mix(inNineGrid.y, inNineGrid.w, rectUV.x),
        mix(inNineGrid.x, inNineGrid.z, rectUV.y)
    );
}


void main() {
    if (inSizing.z <= 0.0 || inSizing.w <= 0.0) {
        outFragColor = vec4(0.0);
        return;
    }

    // mat4 transform = mat4(inTransformC1, inTransformC2, inTransformC3, inTransformC4);
    // vec2 localPos = (transform * vec4(gl_FragCoord.xy, 0.0, 1.0)).xy;
    // vec2 localCenter = (transform * vec4(inSizing.xy + inSizing.zw / 2.0, 0.0, 1.0)).xy;
    vec2 relativeOffset = inRelativeOffset;

    vec2 box = inSizing.zw / 2;
    float cornerDegree = inCornerDegreeAndBorderWidthAndVertexPos.x;
    float borderWidth = max(inCornerDegreeAndBorderWidthAndVertexPos.y, 0.0);

    float mode = inOpacityScreenSizeAndMode.w;
    vec4 result;

    vec2 rectUV = clamp((relativeOffset + box) / max(inSizing.zw, vec2(1e-4)), 0.0, 1.0);

    if (mode > 0.5) {
        // Shadow mode
        vec4 shadowLayer = vec4(0.0);
        float shadowBlur = max(inShadow.z, 0.0);
        if (inColor.a > 0.0) {
            vec2 ps = relativeOffset - inShadow.xy;
            float spread = inShadow.w;
            vec2 shadowHalfBox = max(box + vec2(spread), vec2(0.0));
            vec4 shadowRadii = max(inCornerRadius + vec4(spread), vec4(0.0));
            float ds = sdRoundedRectSuperellipse(ps, shadowHalfBox, shadowRadii, cornerDegree);

            float shadowCoverage;
            if (shadowBlur > 0.0) {
                // float t = ds / max(shadowBlur, 1e-4);
                // erfApprox(0) = 0 -> 0.5
                // erfApprox(-inf) = -1 -> 1.0
                // erfApprox(inf) = 1 -> 0.0
                shadowCoverage = 0.5 - 0.5 * smoothstep(0, shadowBlur, ds);
            } else {
                shadowCoverage = ds <= 0.0 ? 1.0 : 0.0;
            }
            shadowLayer = vec4(inColor.rgb, inColor.a * clamp(shadowCoverage, 0.0, 1.0));
        }
        result = shadowLayer;

    } else {
        // Shape mode
        float d = sdRoundedRectSuperellipse(relativeOffset, box, inCornerRadius, cornerDegree);
        float outerCoverage = sdfCoverage(d);

        float fillCoverage = outerCoverage;
        float borderCoverage = 0.0;
        if (borderWidth > 0.0) {
            float innerCoverage = sdfCoverage(d + borderWidth);
            fillCoverage = innerCoverage;
            borderCoverage = max(outerCoverage - innerCoverage, 0.0);
        }

        vec4 interior = inColor;
        bool hasContent = inContentsAndMask.x != 0u;
        if (hasContent) {
            vec2 uv = contentUVFromRectUV(rectUV);
            vec4 texel = texture(renderTextures[nonuniformEXT(inContentsAndMask.y)], uv);
            vec4 contentColor = texel;

            bool looksSingleChannel =
                texel.a > 0.999
                && abs(texel.g) < 1e-5
                && abs(texel.b) < 1e-5;
            if (looksSingleChannel) {
                contentColor = vec4(inTintColor.rgb, texel.r * inTintColor.a);
            } else {
                contentColor *= inTintColor;
            }

            interior = over(contentColor, interior);
        }

        vec4 fillLayer = vec4(interior.rgb, interior.a * fillCoverage);
        vec4 borderLayer = vec4(inBorderColor.rgb, inBorderColor.a * borderCoverage);
        vec4 shapeLayer = over(borderLayer, fillLayer);
        
        result = shapeLayer;
    }

    bool hasMask = inContentsAndMask.z != 0u;
    if (hasMask) {
        vec4 maskTexel = texture(renderTextures[nonuniformEXT(inContentsAndMask.w)], rectUV);
        float maskAlpha = sampledAlpha(maskTexel);
        result.a *= maskAlpha;
    }

    float opacity = clamp(inOpacityScreenSizeAndMode.x, 0.0, 1.0);
    result.a *= opacity;
    outFragColor = result;

}
