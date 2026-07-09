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

// MARK: - Regular polygon / star SDFs (ported from https://iquilezles.org/articles/distfunctions2d/)
// `radius` is the circumradius; iq's functions take the inradius/tip radius, so we rescale here.

public float sdfPentagon(float2 p, float radius) {
  float r = radius * 0.809016994; // circumradius -> inradius
  const float3 k = float3(0.809016994, 0.587785252, 0.726542528);
  p.x = abs(p.x);
  p -= 2.0 * min(dot(float2(-k.x, k.y), p), 0.0) * float2(-k.x, k.y);
  p -= 2.0 * min(dot(float2( k.x, k.y), p), 0.0) * float2( k.x, k.y);
  p -= float2(clamp(p.x, -r * k.z, r * k.z), r);
  return length(p) * sign(p.y);
}

public float sdfHexagon(float2 p, float radius) {
  float r = radius * 0.866025404; // circumradius -> inradius
  const float3 k = float3(-0.866025404, 0.5, 0.577350269);
  p = abs(p);
  p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
  p -= float2(clamp(p.x, -k.z * r, k.z * r), r);
  return length(p) * sign(p.y);
}

public float sdfOctagon(float2 p, float radius) {
  float r = radius * 0.923879533; // circumradius -> inradius
  const float3 k = float3(-0.9238795325, 0.3826834323, 0.4142135623);
  p = abs(p);
  p -= 2.0 * min(dot(float2( k.x, k.y), p), 0.0) * float2( k.x, k.y);
  p -= 2.0 * min(dot(float2(-k.x, k.y), p), 0.0) * float2(-k.x, k.y);
  p -= float2(clamp(p.x, -k.z * r, k.z * r), r);
  return length(p) * sign(p.y);
}

public float sdfHexagram(float2 p, float radius) {
  float r = radius * 0.5; // circumradius (tip) -> iq r
  const float4 k = float4(-0.5, 0.8660254038, 0.5773502692, 1.7320508076);
  p = abs(p);
  p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
  p -= 2.0 * min(dot(k.yx, p), 0.0) * k.yx;
  p -= float2(clamp(p.x, r * k.z, r * k.w), r);
  return length(p) * sign(p.y);
}

public float sdfPentagram(float2 p, float radius, float rf) {
  const float2 k1 = float2(0.809016994375, -0.587785252292);
  const float2 k2 = float2(-k1.x, k1.y);
  p.x = abs(p.x);
  p -= 2.0 * max(dot(k1, p), 0.0) * k1;
  p -= 2.0 * max(dot(k2, p), 0.0) * k2;
  p.x = abs(p.x);
  p.y -= radius;
  float2 ba = rf * float2(-k1.y, k1.x) - float2(0.0, 1.0);
  float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, radius);
  return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

public float sdfQuadraticCircle(float2 p, float radius) {
  p = abs(p / radius);
  if (p.y > p.x) p = p.yx;
  float a = p.x - p.y;
  float b = p.x + p.y;
  float c = (2.0 * b - 1.0) / 3.0;
  float h = a * a + c * c * c;
  float t;
  if (h >= 0.0) {
    h = sqrt(h);
    t = sign(h - a) * pow(abs(h - a), 1.0 / 3.0) - pow(h + a, 1.0 / 3.0);
  } else {
    float z = sqrt(-c);
    float v = acos(a / (c * z)) / 3.0;
    t = -z * (cos(v) + sin(v) * 1.732050808);
  }
  t *= 0.5;
  float2 w = float2(-t, t) + 0.75 - t * t - p;
  return length(w) * sign(a * a * 0.5 + b - 1.5) * radius;
}

// arbitrary closed polygon; caller supplies the vertex slice
public float sdfPolygon(float2 p, StructuredBuffer<float2> verts, uint startIndex, uint count) {
  float2 v0 = verts[startIndex];
  float d = dot(p - v0, p - v0);
  float s = 1.0;
  uint j = count - 1;
  for (uint i = 0; i < count; i++) {
    float2 vi = verts[startIndex + i];
    float2 vj = verts[startIndex + j];
    float2 e = vj - vi;
    float2 w = p - vi;
    float2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    d = min(d, dot(b, b));
    bool3 c = bool3(p.y >= vi.y, p.y < vj.y, e.x * w.y > e.y * w.x);
    if (all(c) || all(!c)) s = -s;
    j = i;
  }
  return s * sqrt(d);
}

// MARK: - unary operators (https://iquilezles.org/articles/distfunctions2d/)

// grow outward by r, rounding convex corners
public float opRound(float d, float r) {
  return d - r;
}

// hollow into an annular ring of half-thickness r
public float opOnion(float d, float r) {
  return abs(d) - r;
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