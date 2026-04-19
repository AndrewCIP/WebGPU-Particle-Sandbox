export const PARTICLE_SHAPES = [
  { id: "shape-square", label: "Q: Square", bit: 1 << 0, key: "q" },
  { id: "shape-circle", label: "W: Circle", bit: 1 << 1, key: "w" },
  { id: "shape-triangle", label: "E: Triangle", bit: 1 << 2, key: "e" },
  { id: "shape-star", label: "Z: Star", bit: 1 << 3, key: "z" },
  { id: "shape-square-hollow", label: "A: □", bit: 1 << 4, key: "a" },
  { id: "shape-circle-hollow", label: "S: ○", bit: 1 << 5, key: "s" },
  { id: "shape-triangle-hollow", label: "D: △", bit: 1 << 6, key: "d" },
  { id: "shape-star-hollow", label: "X: ☆", bit: 1 << 7, key: "x" },
];

export const ALL_PARTICLE_SHAPE_MASK = PARTICLE_SHAPES.reduce((mask, shape) => mask | shape.bit, 0);
export const DEFAULT_PARTICLE_SHAPE_MASK = PARTICLE_SHAPES[0].bit;

export function normalizeParticleShapeMask(mask) {
  const normalizedMask = (mask | 0) & ALL_PARTICLE_SHAPE_MASK;
  return normalizedMask === 0 ? DEFAULT_PARTICLE_SHAPE_MASK : normalizedMask;
}

export function toggleParticleShape(mask, bit) {
  const currentMask = normalizeParticleShapeMask(mask);
  const nextMask = currentMask ^ bit;
  return nextMask === 0 ? currentMask : nextMask;
}

