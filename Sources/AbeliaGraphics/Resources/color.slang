// claude wrote this

// ---- sRGB transfer (encoded <-> linear), exact piecewise ----
public float3 srgbToLinear(float3 c) {
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(lo, hi, step(0.04045, c));
}
public float3 linearToSrgb(float3 c) {            // also the Display-P3 encode
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    return lerp(lo, hi, step(0.0031308, c));
}

// ---- OKLCH -> OKLab -> linear sRGB (Ottosson) ----
public float3 oklchToOklab(float3 lch) {          // lch = (L, C, H), H in RADIANS
    return float3(lch.x, lch.y * cos(lch.z), lch.y * sin(lch.z));
}
public float3 oklabToLinearSrgb(float3 lab) {
    float L = lab.x, a = lab.y, bb = lab.z;
    float l_ = L + 0.3963377774 * a + 0.2158037573 * bb;
    float m_ = L - 0.1055613458 * a - 0.0638541728 * bb;
    float s_ = L - 0.0894841775 * a - 1.2914855480 * bb;
    float l = l_*l_*l_, m = m_*m_*m_, s = s_*s_*s_;
    return float3(
         4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

// ---- linear sRGB <-> linear Display-P3 (D65, primaries-only 3x3) ----
public float3 linearSrgbToLinearP3(float3 c) {
    return float3(
        0.8224621 * c.r + 0.1775380 * c.g + 0.0       * c.b,
        0.0331941 * c.r + 0.9668058 * c.g + 0.0       * c.b,
        0.0170827 * c.r + 0.0723974 * c.g + 0.9105199 * c.b);
}
public float3 linearP3ToLinearSrgb(float3 c) {
    return float3(
         1.2249402 * c.r - 0.2249402 * c.g + 0.0       * c.b,
        -0.0420569 * c.r + 1.0420569 * c.g + 0.0       * c.b,
        -0.0196376 * c.r - 0.0786361 * c.g + 1.0982737 * c.b);
}

// ---- the four you asked for (all return LINEAR) ----
public float3 oklchToSrgb(float3 lch) { return oklabToLinearSrgb(oklchToOklab(lch)); }
public float3 oklchToP3  (float3 lch) { return linearSrgbToLinearP3(oklchToSrgb(lch)); }
public float3 rgbToP3    (float3 c)   { return linearSrgbToLinearP3(c); }   // linear sRGB in
float3 p3ToRgb    (float3 c)   { return linearP3ToLinearSrgb(c); }   // linear P3 in
