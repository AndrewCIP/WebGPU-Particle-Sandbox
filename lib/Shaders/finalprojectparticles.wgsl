struct Particle {
  p: vec2f,
  v: vec2f,
  life: f32,
  size: f32,
  color: vec3f,
};

struct InputState {
  mousePos: vec2f,
  clickMode: f32,
  simMode: f32,
  forceStrength: f32,
  damping: f32,
  particleScale: f32,
  pad: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4f,
  @location(0) color: vec4f,
};

@group(0) @binding(0) var<storage, read> particlesIn: array<Particle>;
@group(0) @binding(1) var<storage, read_write> particlesOut: array<Particle>;
@group(0) @binding(2) var<uniform> inputState: InputState;

@vertex
fn vertexMain(
  @builtin(vertex_index) vIdx: u32,
  @builtin(instance_index) pIdx: u32
) -> VertexOut {
  let p = particlesIn[pIdx];

  let speed = length(p.v);
  let brightness = clamp(0.45 + speed * 30.0, 0.45, 1.25);

  let baseHalfSize = 0.001;
  let halfSize = baseHalfSize * p.size * inputState.particleScale;

  var offset = vec2f(0.0, 0.0);

  switch (vIdx) {
    case 0u: { offset = vec2f(-halfSize, -halfSize); }
    case 1u: { offset = vec2f( halfSize, -halfSize); }
    case 2u: { offset = vec2f( halfSize,  halfSize); }
    case 3u: { offset = vec2f(-halfSize, -halfSize); }
    case 4u: { offset = vec2f( halfSize,  halfSize); }
    default: { offset = vec2f(-halfSize,  halfSize); }
  }

  var out: VertexOut;
  out.pos = vec4f(p.p + offset, 0.0, 1.0);
  out.color = vec4f(p.color * brightness, 1.0);
  return out;
}

@fragment
fn fragmentMain(@location(0) color: vec4f) -> @location(0) vec4f {
  return color;
}

@compute @workgroup_size(256)
fn computeMain(@builtin(global_invocation_id) gid: vec3u) {
  let idx = gid.x;
  if (idx >= arrayLength(&particlesIn)) { return; }

  var p = particlesIn[idx];

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