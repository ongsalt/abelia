module sdf_shapes;

public float sdfRoundRect(float2 position, float2 size, float radius, float degree) {
  float2 halfSize = size / 2;
  float2 v = abs(position) - halfSize + radius;
  let m = max(v, 0);
  float outer = pow(pow(m.x, degree) + pow(m.y, degree), 1 / degree);

  // inner + outer - bias (cuz this is rounded)
  return min(0, max(v.x, v.y)) + outer - radius;
}

// arc pointing up (+Y), angle is total arc span in radians, thickness is stroke width
public float sdfArc(float2 p, float radius, float angle, float thickness) {
  float s = sin(angle * 0.5);
  float c = cos(angle * 0.5);
  p.x = abs(p.x);
  return ((c * p.x > s * p.y) ? length(p - float2(s, c) * radius) : abs(length(p) - radius)) - thickness * 0.5;
}

// pie/wedge pointing up (+Y), angle is total arc span in radians
public float sdfPie(float2 p, float radius, float angle, float perimeterOffset) {
  float s = sin(angle * 0.5);
  float c = cos(angle * 0.5);
  p.x = abs(p.x);
  float l = length(p) - radius;
  float m = length(p - float2(s, c) * clamp(dot(p, float2(s, c)), 0.0, radius));
  return max(l, m * sign(c * p.x - s * p.y)) - perimeterOffset;
}

// copied from https://www.shadertoy.com/view/4sS3zz
public float sdfEllipse(float2 position, float2 size) {
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

public float sdfSmoothIntersect(float d1, float d2, float k) {
  return -sdfSmoothUnion(-d1, -d2, k);
}

// removes d2 from d1: smooth max(d1, -d2)
public float sdfSmoothSubtract(float d1, float d2, float k) {
  return -sdfSmoothUnion(-d1, d2, k);
}