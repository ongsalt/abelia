module sdf_shapes;

public float sdfRoundRect(float2 position, float2 size, float radius, float degree) {
  float2 halfSize = size / 2;
  float2 v = abs(position) - (halfSize - radius);
  float2 m = max(v, 0.0);
  float l = pow(pow(m.x, degree) + pow(m.y, degree), 1 / degree);

  return min(0, max(v.x, v.y)) + l - radius;
}

// copied from https://www.shadertoy.com/view/4sS3zz
float sdfEllipse(float2 position, float2 size) {
  position = abs(position);
  if (position.x > position.y) {
    position = position.yx;
    size = size.yx;
  }
  float l = size.y * size.y - size.x * size.x;
  float m = size.x * position.x / l;
  float m2 = m * m;
  float n = size.y * position.y / l;
  float n2 = n * n;
  float c = (m2 + n2 - 1.0) / 3.0;
  float c3 = c * c * c;
  float q = c3 + m2 * n2 * 2.0;
  float d = c3 + m2 * n2;
  float g = m + m * n2;
  float co;
  if (d < 0.0) {
    float h = acos(q / c3) / 3.0;
    float s = cos(h);
    float t = sin(h) * sqrt(3.0);
    float rx = sqrt(-c * (s + t + 2.0) + m2);
    float ry = sqrt(-c * (s - t + 2.0) + m2);
    co = (ry + sign(l) * rx + abs(g) / (rx * ry) - m) / 2.0;
  } else {
    float h = 2.0 * m * n * sqrt(d);
    float s = sign(q + h) * pow(abs(q + h), 1.0 / 3.0);
    float u = sign(q - h) * pow(abs(q - h), 1.0 / 3.0);
    float rx = -s - u - c * 4.0 + 2.0 * m2;
    float ry = (s - u) * sqrt(3.0);
    float rm = sqrt(rx * rx + ry * ry);
    co = (ry / sqrt(rm - rx) + 2.0 * g / rm - m) / 2.0;
  }
  float2 r = size * float2(co, sqrt(1.0 - co * co));
  return length(r - position) * sign(position.y - r.y);
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