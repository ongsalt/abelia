module sdf_shapes;

public float sdfRoundRect(float2 position, float2 size, float radius, float degree) {
  float2 halfSize = size / 2;
  float2 v = abs(position) - (halfSize - radius);

  return min(0, max(v.x, v.y)) - radius;
}

public float sdfSmoothUnion(float d1, float d2, float smoothing) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / smoothing, 0.0, 1.0);
  return lerp(d2, d1, h) - smoothing * h * (1.0 - h);
}


// public float sdfSmoothIntersect(float d1, float d2, float smoothing) {
//   float h = clamp(0.5 + 0.5 * (d2 - d1) / smoothing, 0.0, 1.0);
//   return lerp(d2, d1, h) - smoothing * h * (1.0 - h);
// }

// public float sdfSmoothSubtract(float d1, float d2, float smoothing) {
//   float h = clamp(0.5 + 0.5 * (d2 - d1) / smoothing, 0.0, 1.0);
//   return lerp(d2, d1, h) - smoothing * h * (1.0 - h);
// }