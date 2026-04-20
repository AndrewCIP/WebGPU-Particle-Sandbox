import SceneObject from './SceneObject.js';

const FIRE_COLOR_BASE = [1.0, 0.25, 0.02];
const FIRE_COLOR_TIP = [1.0, 0.82, 0.2];
const RAIN_COLOR_DARK = [0.2, 0.55, 0.95];
const RAIN_COLOR_LIGHT = [0.45, 0.9, 1.0];

export default class FinalProjectParticleSystemObject extends SceneObject {
  constructor(device, canvasFormat, shaderFile, numParticles = 4096) {
    super(device, canvasFormat, shaderFile);
    this._numParticles = numParticles;
    this._activeParticleCount = numParticles;
    this._step = 0;

    this._inputData = new Float32Array(16);
    this._inputBuffer = this._device.createBuffer({
      size: this._inputData.byteLength,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
  }

  async init() {
    await this.createGeometry();
    await this.createShaders();
    await this.createRenderPipeline();
    await this.createComputePipeline();
  }

  async createGeometry() {
    // x, y, prevX, prevY, vx, vy, life, size, r, g, b, a
    this._particles = new Float32Array(this._numParticles * 12);

    this._particleBuffers = [
      this._device.createBuffer({
        size: this._particles.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
      }),
      this._device.createBuffer({
        size: this._particles.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
      }),
    ];

    this.resetParticles();
  }

  resetParticles() {
    const colorMode = Number.isFinite(this._inputData[8]) ? Math.max(0, Math.min(7, Math.floor(this._inputData[8]))) : 0;
    for (let i = 0; i < this._numParticles; i++) {
      const j = i * 12;

      const x = Math.random() * 2 - 1;
      const y = Math.random() * 2 - 1;

      this._particles[j + 0] = x;
      this._particles[j + 1] = y;
      this._particles[j + 2] = x;
      this._particles[j + 3] = y;

      this._particles[j + 4] = (Math.random() * 2 - 1) * 0.01;
      this._particles[j + 5] = (Math.random() * 2 - 1) * 0.01;

      this._particles[j + 6] = 100 + Math.random() * 100;
      this._particles[j + 7] = 1.0;

      const [r, g, b] = this.getColorForMode(colorMode);
      this._particles[j + 8] = r;
      this._particles[j + 9] = g;
      this._particles[j + 10] = b;
      this._particles[j + 11] = 1.0;
    }

    this._device.queue.writeBuffer(this._particleBuffers[0], 0, this._particles);
    this._step = 0;
  }

  setActiveParticleCount(count) {
    this._activeParticleCount = Math.max(0, Math.min(this._numParticles, Math.floor(count)));
  }

  updateInput(input) {
    this._inputData[0] = input.x;
    this._inputData[1] = input.y;
    this._inputData[2] = input.clickMode;
    this._inputData[3] = input.simMode;
    this._inputData[4] = input.forceStrength;
    this._inputData[5] = input.damping;
    this._inputData[6] = input.particleScale;
    this._inputData[7] = input.trailsEnabled;
    this._inputData[8] = input.colorMode || 0;
    this._inputData[9] = this._step;

    this._device.queue.writeBuffer(this._inputBuffer, 0, this._inputData);

    if (typeof input.activeParticleCount === "number") {
      this.setActiveParticleCount(input.activeParticleCount);
    }
    if (typeof input.consumeResetRequest === "function" ? input.consumeResetRequest() : input.resetRequested) {
      this.resetParticles();
    }
  }

  getColorForMode(colorMode) {
    switch (colorMode) {
      case 1: {
        const t = Math.random();
        return [
          FIRE_COLOR_BASE[0] + (FIRE_COLOR_TIP[0] - FIRE_COLOR_BASE[0]) * t,
          FIRE_COLOR_BASE[1] + (FIRE_COLOR_TIP[1] - FIRE_COLOR_BASE[1]) * t,
          FIRE_COLOR_BASE[2] + (FIRE_COLOR_TIP[2] - FIRE_COLOR_BASE[2]) * t,
        ];
      }
      case 2: {
        const t = Math.random();
        return [
          RAIN_COLOR_DARK[0] + (RAIN_COLOR_LIGHT[0] - RAIN_COLOR_DARK[0]) * t,
          RAIN_COLOR_DARK[1] + (RAIN_COLOR_LIGHT[1] - RAIN_COLOR_DARK[1]) * t,
          RAIN_COLOR_DARK[2] + (RAIN_COLOR_LIGHT[2] - RAIN_COLOR_DARK[2]) * t,
        ];
      }
      case 3:
        return [0.9, 0.9, 0.9];
      case 4:
        return [0.2, 0.8, 0.2];
      case 5:
        return [1.0, 0.2, 0.8];
      case 6:
        return [0.8, 0.2, 1.0];
      case 7:
        return [1.0, 1.0, 0.2];
      default:
        return [Math.random(), Math.random(), Math.random()];
    }
  }

  async createShaders() {
    await super.createShaders();

    this._bindGroupLayout = this._device.createBindGroupLayout({
      entries: [
        {
          binding: 0,
          visibility: GPUShaderStage.VERTEX | GPUShaderStage.COMPUTE,
          buffer: { type: "read-only-storage" },
        },
        {
          binding: 1,
          visibility: GPUShaderStage.COMPUTE,
          buffer: { type: "storage" },
        },
        {
          binding: 2,
          visibility: GPUShaderStage.VERTEX | GPUShaderStage.COMPUTE,
          buffer: { type: "uniform" },
        },
      ],
    });

    this._pipelineLayout = this._device.createPipelineLayout({
      bindGroupLayouts: [this._bindGroupLayout],
    });
  }

  async createRenderPipeline() {
    this._pipeline = this._device.createRenderPipeline({
      layout: this._pipelineLayout,
      vertex: {
        module: this._shaderModule,
        entryPoint: "vertexMain",
      },
      fragment: {
        module: this._shaderModule,
        entryPoint: "fragmentMain",
        targets: [{
          format: this._canvasFormat,
        }]
      },
      primitive: { topology: "triangle-list" },
    });

    this._bindGroups = [
      this._device.createBindGroup({
        layout: this._pipeline.getBindGroupLayout(0),
        entries: [
          { binding: 0, resource: { buffer: this._particleBuffers[0] } },
          { binding: 1, resource: { buffer: this._particleBuffers[1] } },
          { binding: 2, resource: { buffer: this._inputBuffer } },
        ],
      }),
      this._device.createBindGroup({
        layout: this._pipeline.getBindGroupLayout(0),
        entries: [
          { binding: 0, resource: { buffer: this._particleBuffers[1] } },
          { binding: 1, resource: { buffer: this._particleBuffers[0] } },
          { binding: 2, resource: { buffer: this._inputBuffer } },
        ],
      })
    ];
  }

  render(pass) {
    pass.setPipeline(this._pipeline);
    pass.setBindGroup(0, this._bindGroups[this._step % 2]);
    pass.draw(6, this._activeParticleCount);
  }

  async createComputePipeline() {
    this._computePipeline = this._device.createComputePipeline({
      layout: this._pipelineLayout,
      compute: {
        module: this._shaderModule,
        entryPoint: "computeMain",
      }
    });
  }

  compute(pass) {
    if (this._activeParticleCount <= 0) {
      return;
    }
    pass.setPipeline(this._computePipeline);
    pass.setBindGroup(0, this._bindGroups[this._step % 2]);
    pass.dispatchWorkgroups(Math.ceil(this._activeParticleCount / 256));
    this._step++;
  }
}
