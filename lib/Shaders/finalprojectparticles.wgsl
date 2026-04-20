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
};

struct VertexOut {
  @builtin(position) pos: vec4f,
  @location(0) color: vec4f,
};

const FIRE_BASE_X: f32 = 0.0;
const FIRE_BASE_Y: f32 = -0.8;
const FIRE_RESPAWN_Y: f32 = 1.05;
const FIRE_MAX_SPREAD: f32 = 0.7;
const FIRE_SEED_MULTIPLIER: f32 = 12.9898;
const FIRE_MIN_LIFE: f32 = 45.0;
const FIRE_LIFE_RANGE: f32 = 80.0;
const FIRE_COLOR_BASE: vec3f = vec3f(1.0, 0.25, 0.02);
const FIRE_COLOR_TIP: vec3f = vec3f(1.0, 0.82, 0.2);

const RAIN_SPAWN_TOP: f32 = 1.0;
const RAIN_SEED_MULTIPLIER: f32 = 78.233;
const RAIN_MIN_LIFE: f32 = 75.0;
const RAIN_LIFE_RANGE: f32 = 90.0;
const RAIN_COLOR_DARK: vec3f = vec3f(0.2, 0.55, 0.95);
const RAIN_COLOR_LIGHT: vec3f = vec3f(0.45, 0.9, 1.0);

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

fn rand(seed: f32) -> f32 {
  // Deterministic pseudo-random hash for shader variation; outputs values in [0, 1).
  return fract(sin(seed) * 43758.5453123);
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
    let idxSeed = f32(idx) * FIRE_SEED_MULTIPLIER;

    p.life -= 1.0;
    let isLifeExpired = p.life <= 0.0;
    let isTooHigh = p.p.y > FIRE_RESPAWN_Y;
    let isTooFarFromCenter = abs(p.p.x - FIRE_BASE_X) > FIRE_MAX_SPREAD;

    if (isLifeExpired || isTooHigh || isTooFarFromCenter) {
      let spawnOffset = (rand(idxSeed + p.prevP.x * 91.7) * 2.0 - 1.0) * 0.08;
      p.p = vec2f(FIRE_BASE_X + spawnOffset, FIRE_BASE_Y);
      p.prevP = p.p;
      p.v = vec2f(
        (rand(idxSeed + 17.0 + p.prevP.y * 43.3) * 2.0 - 1.0) * 0.006,
        0.01 + rand(idxSeed + 31.0) * 0.01
      );
      p.life = FIRE_MIN_LIFE + rand(idxSeed + 53.0) * FIRE_LIFE_RANGE;
    }

    let flicker = (rand(idxSeed + p.life * 0.13) * 2.0 - 1.0) * 0.0008;
    p.v.x += flicker;
    p.v.y += 0.00055 + rand(idxSeed + p.life * 0.07) * 0.00035;
    p.v *= 0.985;

    let rise = clamp((p.p.y - FIRE_BASE_Y) / 1.8, 0.0, 1.0);
    let lifeFade = clamp(p.life / 125.0, 0.0, 1.0);
    p.color = vec4f(
      mix(FIRE_COLOR_BASE, FIRE_COLOR_TIP, 1.0 - rise),
      clamp((1.0 - rise) * lifeFade, 0.0, 1.0)
    );
  }

  if (inputState.simMode == 6.0) {
    let idxSeed = f32(idx) * RAIN_SEED_MULTIPLIER;

    p.life -= 1.0;
    p.v.y -= 0.0009 + inputState.forceStrength * 0.25;
    p.v.x *= 0.995;
    p.v.y *= 0.999;

    if (p.life <= 0.0 || p.p.y < -1.0) {
      let spawnXRand = rand(idxSeed + p.prevP.y * 17.0);
      let spawnYRand = rand(idxSeed + p.prevP.x * 29.0);
      let velocityRandX = rand(idxSeed + 41.0);
      let velocityRandY = rand(idxSeed + 67.0);
      let lifeRand = rand(idxSeed + 79.0);
      let spawnX = spawnXRand * 2.0 - 1.0;
      let spawnY = RAIN_SPAWN_TOP + spawnYRand * 0.08;
      p.p = vec2f(spawnX, spawnY);
      p.prevP = p.p;
      p.v = vec2f(
        (velocityRandX * 2.0 - 1.0) * 0.0015,
        -(0.01 + velocityRandY * 0.015)
      );
      p.life = RAIN_MIN_LIFE + lifeRand * RAIN_LIFE_RANGE;
    }

    let rainColorMix = rand(idxSeed + p.life * 0.11);
    p.color = vec4f(
      mix(RAIN_COLOR_DARK, RAIN_COLOR_LIGHT, rainColorMix),
      0.7
    );
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

  if (inputState.simMode != 5.0 && inputState.simMode != 6.0) {
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
  }

  particlesOut[idx] = p;
}
