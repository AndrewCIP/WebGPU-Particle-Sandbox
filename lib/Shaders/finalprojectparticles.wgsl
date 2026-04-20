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
  _paddingAlignment0: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4f,
  @location(0) color: vec4f,
  @location(1) localPos: vec2f,
  @location(2) trailsFlag: f32,
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
  out.trailsFlag = inputState.trailsEnabled;
  return out;
}

@fragment
fn fragmentMain(in: VertexOut) -> @location(0) vec4f {
  if (in.trailsFlag == 1.0) {
    return in.color;
  }

  let alpha = 1.0 - smoothstep(0.95, 1.0, length(in.localPos));

  if (alpha < 0.01) {
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
