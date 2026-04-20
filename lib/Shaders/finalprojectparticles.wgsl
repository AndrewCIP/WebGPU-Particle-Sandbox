struct Particle {
  p: vec2f,
  prevP: vec2f,
  v: vec2f,
  life: f32,
  size: f32,
  color: vec4f,
};

struct InputState {
  mousePos: vec2f,
  clickMode: f32,
  simMode: f32,
  forceStrength: f32,
  damping: f32,
  particleScale: f32,
  trailsEnabled: f32,
  particleShapeMask: f32,
  _paddingAlignment0: f32,
  _paddingAlignment1: f32,
  _paddingAlignment2: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4f,
  @location(0) color: vec4f,
  @location(1) localPos: vec2f,
  @location(2) shapeId: f32,
  @location(3) trailsFlag: f32,
};

@group(0) @binding(0) var<storage, read> particlesIn: array<Particle>;
@group(0) @binding(1) var<storage, read_write> particlesOut: array<Particle>;
@group(0) @binding(2) var<uniform> inputState: InputState;

fn quadCorner(vIdx: u32) -> vec2f {
  switch (vIdx) {
    case 0u: { return vec2f(-1.0, -1.0); }
    case 1u: { return vec2f( 1.0, -1.0); }
    case 2u: { return vec2f( 1.0,  1.0); }
    case 3u: { return vec2f(-1.0, -1.0); }
    case 4u: { return vec2f( 1.0,  1.0); }
    default: { return vec2f(-1.0,  1.0); }
  }
}

fn isShapeEnabled(mask: u32, shapeId: u32) -> bool {
  return (mask & (1u << shapeId)) != 0u;
}

fn countActiveShapes(mask: u32) -> u32 {
  var count = 0u;
  for (var i = 0u; i < 8u; i = i + 1u) {
    if (isShapeEnabled(mask, i)) {
      count = count + 1u;
    }
  }
  return max(count, 1u);
}

fn shapeForParticle(pIdx: u32, mask: u32) -> u32 {
  let target = pIdx % countActiveShapes(mask);
  var seen = 0u;
  for (var i = 0u; i < 8u; i = i + 1u) {
    if (isShapeEnabled(mask, i)) {
      if (seen == target) {
        return i;
      }
      seen = seen + 1u;
    }
  }
  return 0u;
}

@vertex
fn vertexMain(
  @builtin(vertex_index) vIdx: u32,
  @builtin(instance_index) pIdx: u32
) -> VertexOut {
  let p = particlesIn[pIdx];
  let speed = length(p.v);
  let brightness = clamp(0.45 + speed * 30.0, 0.45, 1.35);

  let baseHalfSize = 0.001;
  let halfSize = baseHalfSize * p.size * inputState.particleScale;

  let corner = quadCorner(vIdx);
  var pos = p.p + corner * halfSize;
  let shapeId = shapeForParticle(pIdx, u32(inputState.particleShapeMask));

  if (inputState.trailsEnabled == 1.0) {
    let segment = p.p - p.prevP;
    let segLen = length(segment);

    if (segLen > 0.0001) {
      let dir = normalize(segment);
      let normal = vec2f(-dir.y, dir.x);

      let tailWidth = halfSize * 0.8;
      let headWidth = halfSize * 0.4;
      let extraLength = min(segLen * 8.0, 0.08);

      let start = p.prevP;
      let end = p.p + dir * extraLength;

      switch (vIdx) {
        case 0u: { pos = start - normal * tailWidth; }
        case 1u: { pos = end   - normal * headWidth; }
        case 2u: { pos = end   + normal * headWidth; }
        case 3u: { pos = start - normal * tailWidth; }
        case 4u: { pos = end   + normal * headWidth; }
        default: { pos = start + normal * tailWidth; }
      }
    }
  }

  var out: VertexOut;
  out.pos = vec4f(pos, 0.0, 1.0);
  out.color = vec4f(p.color.rgb * brightness, p.color.a);
  out.localPos = corner;
  out.shapeId = f32(shapeId);
  out.trailsFlag = inputState.trailsEnabled;
  return out;
}

fn sdBox(p: vec2f, halfExtents: vec2f) -> f32 {
  let d = abs(p) - halfExtents;
  return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

fn sdCircle(p: vec2f, radius: f32) -> f32 {
  return length(p) - radius;
}

fn sdTriangle(pIn: vec2f) -> f32 {
  var p = pIn;
  let k = sqrt(3.0);
  p.x = abs(p.x) - 1.0;
  p.y = p.y + 1.0 / k;
  if (p.x + k * p.y > 0.0) {
    p = vec2f(p.x - k * p.y, -k * p.x - p.y) / 2.0;
  }
  p.x = p.x - clamp(p.x, -2.0, 0.0);
  return -length(p) * sign(p.y);
}

fn sdStar(p: vec2f) -> f32 {
  let angle = atan2(p.y, p.x);
  let radius = length(p);
  let modulation = 0.58 + 0.25 * cos(angle * 5.0);
  return radius - modulation;
}

@fragment
fn fragmentMain(in: VertexOut) -> @location(0) vec4f {
  if (in.trailsFlag == 1.0) {
    return in.color;
  }

  let shapeId = u32(in.shapeId);
  let p = in.localPos;

  var sdf = 1.0;
  if (shapeId == 0u || shapeId == 4u) {
    sdf = sdBox(p, vec2f(0.85, 0.85));
  } else if (shapeId == 1u || shapeId == 5u) {
    sdf = sdCircle(p, 0.85);
  } else if (shapeId == 2u || shapeId == 6u) {
    sdf = sdTriangle(p * 1.05);
  } else if (shapeId == 3u || shapeId == 7u) {
    sdf = sdStar(p * 1.25);
  } else {
    sdf = sdCircle(p, 0.85);
  }

  let edge = 0.03;
  let hollowThickness = 0.12;
  let isHollow = shapeId >= 4u;
  let alpha = select(
    1.0 - smoothstep(-edge, edge, sdf),
    max(1.0 - smoothstep(hollowThickness - edge, hollowThickness + edge, abs(sdf)), 0.0),
    isHollow
  );

  if (alpha <= 0.01) {
    discard;
  }

  return vec4f(in.color.rgb, in.color.a * alpha);
}

@compute @workgroup_size(256)
fn computeMain(@builtin(global_invocation_id) gid: vec3u) {
  let idx = gid.x;
  if (idx >= arrayLength(&particlesIn)) { return; }

  var p = particlesIn[idx];

  p.prevP = p.p;

  let center = vec2f(0.0, 0.0);
  let toMouse = inputState.mousePos - p.p;
  let mouseDist = length(toMouse);

  if (inputState.simMode == 1.0) {
  }

  if (inputState.simMode == 2.0) {
    p.v.y -= inputState.forceStrength * 0.3;
  }

  if (inputState.simMode == 3.0) {
    let dir = p.p - center;
    let dist = length(dir);
    if (dist > 0.001) {
      let norm = normalize(dir);
      p.v += norm * (inputState.forceStrength * 0.4);
    }
  }

  if (inputState.simMode == 4.0) {
    let dir = p.p - center;
    let dist = length(dir);
    if (dist > 0.001) {
      let radial = normalize(dir);
      let tangent = vec2f(-radial.y, radial.x);
      p.v += tangent * (inputState.forceStrength * 0.4);
    }
  }

  if (inputState.simMode == 5.0) {
    let dirToMouse = inputState.mousePos - p.p;
    let distToMouse = length(dirToMouse);

    if (distToMouse > 0.001) {
      let normToMouse = normalize(dirToMouse);
      p.v += normToMouse * (inputState.forceStrength * 0.35);
    }

    p.v *= 0.995;
  }

  if (mouseDist > 0.001) {
    let normMouse = normalize(toMouse);

    if (inputState.clickMode == 1.0) {
      p.v += normMouse * inputState.forceStrength;
    }

    if (inputState.clickMode == 2.0) {
      p.v -= normMouse * inputState.forceStrength;
    }
  }

  p.p += p.v;
  p.v *= inputState.damping;

  if (p.p.x > 1.0) {
    p.p.x = 1.0;
    p.v.x = -p.v.x;
  }
  if (p.p.x < -1.0) {
    p.p.x = -1.0;
    p.v.x = -p.v.x;
  }

  if (p.p.y > 1.0) {
    p.p.y = 1.0;
    p.v.y = -p.v.y;
  }
  if (p.p.y < -1.0) {
    p.p.y = -1.0;
    p.v.y = -p.v.y;
  }

  particlesOut[idx] = p;
}
