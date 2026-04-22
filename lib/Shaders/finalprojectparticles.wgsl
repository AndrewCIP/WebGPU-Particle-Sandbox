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
  time: f32,
  colorMode: f32,
  _padding: vec2f,
};

struct VertexOut {
  @builtin(position) pos: vec4f,
  @location(0) color: vec4f,
};

const FIRE_BASE_X: f32 = 0.0;
const FIRE_BASE_Y: f32 = -0.8;
const FIRE_RESPAWN_Y: f32 = 1.05;
const FIRE_MAX_SPREAD: f32 = 0.85;
const FIRE_BASE_RADIUS: f32 = 0.1;
const FIRE_SEED_MULTIPLIER: f32 = 12.9898;
const FIRE_SPAWN_OFFSET_SEED: f32 = 91.7;
const FIRE_SPAWN_VELOCITY_SEED: f32 = 43.3;
const FIRE_VELOCITY_X_SEED_OFFSET: f32 = 17.0;
const FIRE_VELOCITY_Y_SEED_OFFSET: f32 = 31.0;
const FIRE_ANGLE_SEED_OFFSET: f32 = 113.0;
const FIRE_LIFE_SEED_OFFSET: f32 = 53.0;
const FIRE_FLICKER_SEED: f32 = 0.13;
const FIRE_RISE_SEED: f32 = 0.07;
const FIRE_MIN_LIFE: f32 = 45.0;
const FIRE_LIFE_RANGE: f32 = 80.0;
const FIRE_EPSILON: f32 = 0.0001;
const FIRE_COLOR_BASE: vec3f = vec3f(1.0, 0.25, 0.02);
const FIRE_COLOR_TIP: vec3f = vec3f(1.0, 0.82, 0.2);
const FIRE_DISTANCE_SCALE: f32 = 1024.0;
const FIRE_DISTANCE_MAX: f32 = 255.0;
const FIRE_COLOR_TRANSITION_DISTANCE: f32 = 128.0;
const FIRE_COLOR_CENTER: vec3f = vec3f(253.0 / 255.0, 207.0 / 255.0, 88.0 / 255.0);
const FIRE_COLOR_MID: vec3f = vec3f(242.0 / 255.0, 125.0 / 255.0, 12.0 / 255.0);
const FIRE_COLOR_EDGE: vec3f = vec3f(128.0 / 255.0, 9.0 / 255.0, 9.0 / 255.0);

const RAIN_SPAWN_TOP: f32 = 1.0;
const RAIN_SEED_MULTIPLIER: f32 = 78.233;
const RAIN_SPAWN_X_SEED: f32 = 17.0;
const RAIN_SPAWN_Y_SEED: f32 = 29.0;
const RAIN_VELOCITY_X_SEED_OFFSET: f32 = 41.0;
const RAIN_VELOCITY_Y_SEED_OFFSET: f32 = 67.0;
const RAIN_LIFE_SEED_OFFSET: f32 = 79.0;
const RAIN_COLOR_SEED: f32 = 0.11;
const RAIN_GRAVITY: f32 = 0.0009;
const RAIN_MIN_LIFE: f32 = 75.0;
const RAIN_LIFE_RANGE: f32 = 90.0;
const RAIN_BOUNCE_DAMPING: f32 = 0.45;
const RAIN_BOUNCE_X_JITTER: f32 = 0.0012;
const RAIN_BOUNCE_SEED: f32 = 0.29;
const RAIN_COLOR_DARK: vec3f = vec3f(0.2, 0.55, 0.95);
const RAIN_COLOR_LIGHT: vec3f = vec3f(0.45, 0.9, 1.0);
const TAU: f32 = 6.28318530718;

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

fn selectedColorMode() -> u32 {
  return u32(clamp(inputState.colorMode, 0.0, 7.0));
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
  let colorMode = selectedColorMode();

  p.prevP = p.p;

  let center = vec2f(0.0, 0.0);
  let toMouse = inputState.mousePos - p.p;
  let mouseDist = length(toMouse);

  if (inputState.simMode == 0.0) {
  }

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
    if (p.life <= 0.0 || p.p.y > FIRE_RESPAWN_Y) {
      let spawnOffset = (rand(inputState.time + idxSeed + FIRE_SPAWN_OFFSET_SEED) - 0.5) * 0.2;
      p.p = vec2f(clamp(FIRE_BASE_X + spawnOffset, -FIRE_MAX_SPREAD, FIRE_MAX_SPREAD), FIRE_BASE_Y);
      p.prevP = p.p;
      p.v = vec2f(
        (rand(inputState.time + idxSeed + 10.0) - 0.5) * 0.002,
        0.01 + rand(inputState.time + idxSeed + 20.0) * 0.01
      );
      p.life = 128.0 + rand(inputState.time + idxSeed + 30.0) * 127.0;
    }

    let flicker = (rand(inputState.time + f32(idx)) - 0.5) * 0.0008;
    p.v.x += flicker;
    p.p.x += (0.0 - p.p.x) * 0.15;
    p.v.x *= 0.98;

    let base = vec2f(FIRE_BASE_X, FIRE_BASE_Y);
    let dist = min(length(p.p - base) * FIRE_DISTANCE_SCALE, FIRE_DISTANCE_MAX);
    if (colorMode == 1u) {
      if (dist > FIRE_COLOR_TRANSITION_DISTANCE) {
        let t = (dist - FIRE_COLOR_TRANSITION_DISTANCE) / (FIRE_DISTANCE_MAX - FIRE_COLOR_TRANSITION_DISTANCE);
        p.color = vec4f(FIRE_COLOR_EDGE * t + FIRE_COLOR_MID * (1.0 - t), 1.0);
      } else {
        let t = (FIRE_COLOR_TRANSITION_DISTANCE - dist) / FIRE_COLOR_TRANSITION_DISTANCE;
        p.color = vec4f(FIRE_COLOR_CENTER * t + FIRE_COLOR_MID * (1.0 - t), 1.0);
      }
    }
  }

  if (inputState.simMode == 6.0) {
    let idxSeed = f32(idx) * RAIN_SEED_MULTIPLIER;

    p.life -= 1.0;
    p.v.y -= RAIN_GRAVITY;
    p.v.x *= 0.995;
    p.v.y *= 0.999;

    let hasBounced = p.size < 0.95;
    if (!hasBounced && p.p.y <= -1.0 && p.v.y < 0.0) {
      p.p.y = -1.0;
      p.v.y = abs(p.v.y) * RAIN_BOUNCE_DAMPING;
      p.v.x += (rand(idxSeed + p.life * RAIN_BOUNCE_SEED) * 2.0 - 1.0) * RAIN_BOUNCE_X_JITTER;
      p.size = 0.85;
    }

    if (p.life <= 0.0 || p.p.y < -1.08 || abs(p.p.x) > 1.08 || p.p.y > 1.08) {
      let spawnXRand = rand(idxSeed + RAIN_SPAWN_X_SEED);
      let spawnYRand = rand(idxSeed + RAIN_SPAWN_Y_SEED);
      let velocityRandX = rand(idxSeed + RAIN_VELOCITY_X_SEED_OFFSET);
      let velocityRandY = rand(idxSeed + RAIN_VELOCITY_Y_SEED_OFFSET);
      let lifeRand = rand(idxSeed + RAIN_LIFE_SEED_OFFSET);
      let spawnX = spawnXRand * 2.0 - 1.0;
      let spawnY = RAIN_SPAWN_TOP + spawnYRand * 0.08;
      p.p = vec2f(spawnX, spawnY);
      p.prevP = p.p;
      p.v = vec2f(
        (velocityRandX * 2.0 - 1.0) * 0.0015,
        -(0.01 + velocityRandY * 0.015)
      );
      p.life = RAIN_MIN_LIFE + lifeRand * RAIN_LIFE_RANGE;
      p.size = 1.0;
    }

    let rainColorMix = rand(idxSeed + p.life * RAIN_COLOR_SEED);
    if (colorMode == 2u) {
      p.color = vec4f(
        mix(RAIN_COLOR_DARK, RAIN_COLOR_LIGHT, rainColorMix),
        0.7
      );
    }
  }

  if (colorMode == 0u) {
    let phase = f32(idx) * 0.031;
    p.color = vec4f(
      0.5 + 0.5 * sin(phase),
      0.5 + 0.5 * sin(phase + TAU / 3.0),
      0.5 + 0.5 * sin(phase + 2.0 * TAU / 3.0),
      1.0
    );
  } else if (colorMode == 1u && inputState.simMode != 5.0) {
    let warmMix = rand(f32(idx) * FIRE_SEED_MULTIPLIER + 9.0);
    p.color = vec4f(mix(FIRE_COLOR_BASE, FIRE_COLOR_TIP, warmMix), 1.0);
  } else if (colorMode == 2u && inputState.simMode != 6.0) {
    let coolMix = rand(f32(idx) * RAIN_SEED_MULTIPLIER + 21.0);
    p.color = vec4f(mix(RAIN_COLOR_DARK, RAIN_COLOR_LIGHT, coolMix), 1.0);
  } else if (colorMode == 3u) {
    p.color = vec4f(0.9, 0.9, 0.9, 1.0);
  } else if (colorMode == 4u) {
    p.color = vec4f(0.2, 0.8, 0.2, 1.0);
  } else if (colorMode == 5u) {
    p.color = vec4f(1.0, 0.2, 0.8, 1.0);
  } else if (colorMode == 6u) {
    p.color = vec4f(0.8, 0.2, 1.0, 1.0);
  } else if (colorMode == 7u) {
    p.color = vec4f(1.0, 1.0, 0.2, 1.0);
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
