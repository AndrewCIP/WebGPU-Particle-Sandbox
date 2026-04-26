# WebGPU Particle Sandbox — Technical Documentation

> **Purpose:** Quick, digestible reference for answering live Q&A after project presentations.  
> Each topic is a 2–4 sentence explanation you can speak aloud with confidence.

---

## Table of Contents

1. [Modes](#1-modes)
   - [How Shaders Work](#11-how-shaders-work-wgsl)
   - [How Modes Are Interchangeable](#12-how-modes-are-interchangeable)
2. [Particles](#2-particles)
   - [How the Particle Buffer Is Created and Structured](#21-how-the-particle-buffer-is-created-and-structured)
   - [How Particle Size Works](#22-how-particle-size-works)
   - [How Particle Count Updating Works](#23-how-particle-count-updating-works)
   - [How Color Changing Works](#24-how-color-changing-works)
   - [How Particle Trails Work](#25-how-particle-trails-work)
   - [How the Reset Option Works](#26-how-the-reset-option-works)
3. [Properties](#3-properties)
   - [How the Force Setting Works](#31-how-the-force-setting-works)
   - [How the Damping Setting Works](#32-how-the-damping-setting-works)
4. [HUD (User Interface)](#4-hud-user-interface)
   - [How Buttons Are Made](#41-how-buttons-are-made)
   - [How the Color Is Gradient Blue](#42-how-the-color-is-gradient-blue)
   - [How Buttons Highlight to Green](#43-how-buttons-highlight-to-green)
   - [How Line Segments Are Made](#44-how-line-segments-are-made)
   - [How Font and Different Text Sizes Are Made](#45-how-font-and-different-text-sizes-are-made)
   - [How the Sandbox Title Is Made Above the HUD](#46-how-the-sandbox-title-is-made-above-the-hud)
5. [Other Important Topics](#5-other-important-topics)
   - [Why Mouse Position Doesn't Update Inside the HUD](#51-why-mouse-position-doesnt-update-inside-the-hud)
   - [How Mouse Interaction Works](#52-how-mouse-interaction-works)
   - [How WebGPU Buffers Work](#53-how-webgpu-buffers-work)
   - [How the Compute Pipeline Works](#54-how-the-compute-pipeline-works)
   - [How the Render Pipeline Works](#55-how-the-render-pipeline-works)
   - [GitHub Pages Deployment and ES Modules](#56-github-pages-deployment-and-es-modules)

---

## 1. Modes

### 1.1 How Shaders Work (WGSL)

The project uses **WGSL** (WebGPU Shading Language), which is the native shader language for WebGPU — similar in role to GLSL for OpenGL. All shader code lives in a single file: `lib/Shaders/finalprojectparticles.wgsl`, which contains three entry points:

| Entry Point | Stage | Purpose |
|---|---|---|
| `vertexMain` | Vertex | Positions each particle quad corner on screen |
| `fragmentMain` | Fragment | Outputs the interpolated color to the pixel |
| `computeMain` | Compute | Updates every particle's physics each frame |

The compute shader runs first each frame to advance physics, then the render shader draws the result. The fragment shader is intentionally trivial — it just passes the color through — because all color logic runs in the compute shader.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl

@vertex fn vertexMain(...) -> VertexOut { ... }     // positions quad corners
@fragment fn fragmentMain(...) -> @location(0) vec4f { return color; }
@compute @workgroup_size(256) fn computeMain(...) { ... }  // physics update
```

---

### 1.2 How Modes Are Interchangeable

Each simulation mode is represented as a **float value** (`simMode`) inside the `InputState` uniform struct, which is written to the GPU every frame from JavaScript. Inside `computeMain`, each mode is a separate `if` branch; only the active mode's branch executes for each particle.

Switching modes from the HUD or keyboard only changes one integer in the JavaScript `input` object. On the next frame, `updateInput()` writes the new value to the GPU uniform buffer, and the correct `if` branch fires automatically.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — computeMain
if (inputState.simMode == 2.0) { p.v.y -= inputState.forceStrength * 0.3; }  // Gravity
if (inputState.simMode == 3.0) { /* Explosion outward push */ }
if (inputState.simMode == 4.0) { /* Orbit tangential force */ }
// ...
```

```js
// finalproject.js — keyboard handler
case "2": input.simMode = 2; break;   // sets the uniform that drives the shader branch
```

**Modes 1–7:** Static · Gravity · Explosion · Orbit · Fire · Rain · Cursor

---

## 2. Particles

### 2.1 How the Particle Buffer Is Created and Structured

Each particle is stored as **12 consecutive floats** in a `Float32Array`. Two `GPUBufferUsage.STORAGE` buffers (ping-pong buffers) are allocated on the GPU at startup with `device.createBuffer()`. The compute shader reads from one and writes to the other; they swap roles every frame via `this._step % 2`.

```js
// lib/Scene/FinalProjectParticleSystemObject.js — createGeometry()
// Layout per particle: x, y, prevX, prevY, vx, vy, life, size, r, g, b, a
this._particles = new Float32Array(this._numParticles * 12);

this._particleBuffers = [
  this._device.createBuffer({ size: ..., usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST }),
  this._device.createBuffer({ size: ..., usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST }),
];
```

The corresponding WGSL struct mirrors this layout exactly:

```wgsl
// lib/Shaders/finalprojectparticles.wgsl
struct Particle {
  p: vec2f,     // current position
  prevP: vec2f, // previous position (used for trails)
  v: vec2f,     // velocity
  life: f32,    // remaining life counter
  size: f32,    // per-particle size multiplier
  color: vec4f, // RGBA color
};
```

---

### 2.2 How Particle Size Works

Particle size is controlled by **two multipliers** that combine in the vertex shader: a per-particle `size` field (stored in the buffer) and a global `particleScale` uniform controlled by the `[` / `]` keys or HUD buttons. The vertex shader uses these to compute a half-size, then offsets each of the 6 quad vertices by that amount around the particle's center position.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — vertexMain
let baseHalfSize = 0.001;
let halfSize = baseHalfSize * p.size * inputState.particleScale;
let corner = quadCorner(vIdx);     // one of the 6 corners of two triangles
var pos = p.p + corner * halfSize; // offset from center
```

---

### 2.3 How Particle Count Updating Works

The system always allocates the **maximum** number of particles (4096) in the GPU buffer at startup, but only a subset are actually simulated and drawn. `this._activeParticleCount` controls this: the compute shader dispatch covers only that many threads, and `pass.draw(6, this._activeParticleCount)` renders only that many instances.

```js
// lib/Scene/FinalProjectParticleSystemObject.js
compute(pass) {
  pass.dispatchWorkgroups(Math.ceil(this._activeParticleCount / 256)); // simulate only active
}
render(pass) {
  pass.draw(6, this._activeParticleCount); // draw only active (6 verts × N instances)
}
```

The HUD `+` / `–` buttons and `=` / `-` keyboard shortcuts call `changeParticleCount()` in `hud.js`, which updates `input.activeParticleCount`, clamped to `[0, 999]`.

---

### 2.4 How Color Changing Works

Color is driven by a `colorMode` integer (0–7) that travels through the same `InputState` uniform. In the compute shader, at the end of each frame, a chain of `if/else if` statements sets `p.color` on every particle based on the active color mode. Because color is written **every compute frame**, changing the mode takes effect instantly on the next frame.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — computeMain (color assignment)
if (colorMode == 0u) {
  // Rainbow: HSL-like sine wave based on particle index
  p.color = vec4f(0.5 + 0.5 * sin(phase), ...);
} else if (colorMode == 3u) {
  p.color = vec4f(0.9, 0.9, 0.9, 1.0); // White
} else if (colorMode == 4u) {
  p.color = vec4f(0.2, 0.8, 0.2, 1.0); // Green
} // ...etc.
```

Fire mode (5) and Rain mode (6) have **auto-assigned colors** when their mode's color palette is active, blending based on distance from origin or random seeding.

---

### 2.5 How Particle Trails Work

When trails are enabled, the vertex shader replaces the usual square quad with an **elongated, tapered quad** oriented along the particle's direction of travel. It does this by computing the vector from `prevP` (last frame's position) to `p` (current position), then constructing a normal to that segment and offsetting vertices asymmetrically — wider at the tail, narrower at the head — to create a comet-like streak.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — vertexMain
if (inputState.trailsEnabled == 1.0) {
  let segment = p.p - p.prevP;          // direction of travel
  let dir = normalize(segment);
  let normal = vec2f(-dir.y, dir.x);    // perpendicular to direction

  let tailWidth = halfSize * 0.8;       // wider at back
  let headWidth = halfSize * 0.4;       // narrower at front
  let start = p.prevP;
  let end = p.p + dir * extraLength;    // extend tip slightly

  // 6 vertices forming two triangles as a tapered quad
  switch (vIdx) {
    case 0u: { pos = start - normal * tailWidth; }
    // ...
  }
}
```

`prevP` is updated each compute frame with `p.prevP = p.p` before physics are applied, so it always holds the position from the previous tick.

---

### 2.6 How the Reset Option Works

Resetting re-initializes all particles on the **CPU side** in JavaScript, then uploads the data to the GPU. The `resetParticles()` method in `FinalProjectParticleSystemObject.js` iterates over all `numParticles`, assigns random positions, small random velocities, random life values, and colors based on the current `colorMode`, then calls `device.queue.writeBuffer()` to upload the fresh data to buffer 0 and resets `this._step = 0`.

```js
// lib/Scene/FinalProjectParticleSystemObject.js — resetParticles()
for (let i = 0; i < this._numParticles; i++) {
  const x = Math.random() * 2 - 1;   // random in [-1, 1] normalized space
  const y = Math.random() * 2 - 1;
  this._particles[j + 0] = x;        // position x
  this._particles[j + 4] = (Math.random() * 2 - 1) * 0.01; // velocity x
  // ...
}
this._device.queue.writeBuffer(this._particleBuffers[0], 0, this._particles);
this._step = 0;
```

The reset is triggered by pressing `R` or clicking "R: Reset" in the HUD, which sets `input.resetRequested = true`. On the next frame, `updateInput()` detects this flag and calls `resetParticles()`.

---

## 3. Properties

### 3.1 How the Force Setting Works

`forceStrength` is a scalar uniform value that the compute shader multiplies against directional vectors when applying forces to particle velocity. Higher values mean stronger pushes. For example, in Gravity mode it scales the downward acceleration; in Explosion mode it scales how fast particles fly outward; in Cursor mode it controls how fast particles move toward the mouse.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — computeMain
if (inputState.simMode == 2.0) {
  p.v.y -= inputState.forceStrength * 0.3;  // Gravity: scale downward pull
}
if (inputState.simMode == 3.0) {
  p.v += norm * (inputState.forceStrength * 0.4); // Explosion: scale outward push
}
```

The range is `[0.0002, 0.01]`, adjustable via the `↑` / `↓` keys or the HUD Force buttons.

---

### 3.2 How the Damping Setting Works

Damping is a **velocity multiplier** applied every compute frame — it scales each particle's velocity by a value less than 1.0, causing motion to gradually decay. A value of `0.999` means velocity loses 0.1% per frame (very floaty); `0.96` loses 4% per frame (snappy stop). This simulates friction or air resistance.

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — computeMain (last physics step)
p.p += p.v;           // integrate position
p.v *= inputState.damping;  // decay velocity (e.g. 0.992 → loses ~0.8% per frame)
```

The range is `[0.96, 0.999]`, adjustable with the `←` / `→` keys or HUD Damping buttons.

---

## 4. HUD (User Interface)

### 4.1 How Buttons Are Made

Each button is an instance of the `HUDButton` class defined in `hud.js`. The `create()` method programmatically creates a `<button>` DOM element, assigns it the CSS class `hud-button`, sets the text label, and attaches a `click` event listener. The click handler calls `e.stopPropagation()` to prevent the click from bubbling to the canvas, then invokes the button's callback to change simulator state.

```js
// hud.js — HUDButton.create()
this.element = document.createElement("button");
this.element.className = "hud-button";
this.element.textContent = this.label;
this.element.addEventListener("click", (e) => {
  e.stopPropagation();
  this.callback();
});
```

Buttons are grouped by function (modes, colors, utility) and appended into flex-row containers that are themselves appended to the HUD `<div>`.

---

### 4.2 How the Color Is Gradient Blue

The default button background is set entirely in CSS using `linear-gradient`. The gradient goes at a 135° angle from a semi-transparent medium-blue at the top-left corner to a darker blue at the bottom-right, giving a polished, glassy appearance without any images.

```css
/* finalproject.css — .hud-button */
background: linear-gradient(
  135deg,
  rgba(60, 120, 200, 0.4) 0%,   /* medium blue, 40% opacity */
  rgba(40, 80, 160, 0.3) 100%   /* darker blue, 30% opacity */
);
border: 1.5px solid rgba(100, 150, 200, 0.5);
color: rgba(200, 230, 255, 1);  /* light blue text */
```

The semi-transparent background lets the dark canvas color show through, creating a frosted-glass look.

---

### 4.3 How Buttons Highlight to Green

When a mode or color button is the currently active selection, `HUDButton.setActive(true)` adds the CSS class `active` to the element. The `.hud-button.active` rule overrides the blue gradient with a green gradient, brightens the border, and adds a green box-shadow glow. When the selection changes, `setActive(false)` removes the class and the button reverts to its default blue style.

```js
// hud.js — HUDButton.setActive()
setActive(active) {
  if (active) this.element.classList.add("active");
  else         this.element.classList.remove("active");
}
```

```css
/* finalproject.css — .hud-button.active */
background: linear-gradient(135deg, rgba(80, 200, 80, 0.6) 0%, rgba(60, 160, 60, 0.5) 100%);
border-color: rgba(120, 255, 120, 0.8);
box-shadow: 0 0 10px rgba(100, 255, 100, 0.6), inset 0 0 4px rgba(255, 255, 255, 0.15);
```

---

### 4.4 How Line Segments Are Made

The visual dividers between HUD sections are CSS `border-bottom` properties on `.hud-section` elements — no extra HTML elements are needed. Each section `<div>` gets `border-bottom: 1px solid rgba(100, 150, 255, 0.2)`, creating a subtle blue-tinted horizontal rule. The title at the top uses a thicker `2px` border for emphasis.

```css
/* finalproject.css */
.hud-section {
  border-bottom: 1px solid rgba(100, 150, 255, 0.2); /* section separator */
}
.hud-title {
  border-bottom: 2px solid rgba(100, 150, 255, 0.4); /* thicker title underline */
}
.hud-section:last-child {
  border-bottom: none; /* no line after the last section */
}
```

---

### 4.5 How Font and Different Text Sizes Are Made

All text uses `Arial, sans-serif` set globally on `#hud` and on individual `.hud-button` elements in `finalproject.css`. Different visual hierarchy levels use different `font-size` values declared in CSS class rules — no JavaScript is needed for typography.

| Element | CSS Class | Font Size | Style |
|---|---|---|---|
| Sandbox title | `.hud-title` | `14px`, bold | Light blue color |
| Section headers (MODES, PARTICLES…) | `.hud-section-header` | `11px`, bold, uppercase | Letter-spacing: 1px |
| Labels and buttons | `.hud-label`, `.hud-button` | `11px` | Normal/medium weight |
| Numeric value displays | `.hud-value` | `10px` | Monospace (`Courier New`) |
| Keyboard shortcut info | `.hud-info small` | `10px` | Dimmed blue color |

---

### 4.6 How the Sandbox Title Is Made Above the HUD

The title "Interactive WebGPU Particle Sandbox" is a plain `<div>` element with class `hud-title`, created in JavaScript inside `HUDManager.updateHUD()`. `updateHUD()` first clears the HUD container with `innerHTML = ""`, then appends the title — making it the first element added and therefore the one that appears at the top. Its appearance — larger bold text, a bottom border underline, and a bright cyan color — is entirely CSS.

```js
// hud.js — HUDManager.updateHUD()
this.hudElement.innerHTML = "";  // clear container first
const title = document.createElement("div");
title.className = "hud-title";
title.innerHTML = "<strong>Interactive WebGPU Particle Sandbox</strong>";
this.hudElement.appendChild(title); // appended first → renders at top
```

```css
/* finalproject.css — .hud-title */
font-size: 14px;
font-weight: bold;
color: rgba(100, 200, 255, 1);         /* bright cyan-blue */
border-bottom: 2px solid rgba(100, 150, 255, 0.4);
margin-bottom: 12px;
```

---

## 5. Other Important Topics

### 5.1 Why Mouse Position Doesn't Update Inside the HUD

Mouse movement events are only listened to on the **`canvas` element**, not on the whole `window`. When the mouse moves over the HUD `<div>`, the event target is the HUD (which sits on top of the canvas in the DOM), so the canvas `mousemove` listener never fires. Additionally, the HUD has `pointer-events: auto` in CSS, which means it fully captures mouse events and they do not pass through to the canvas beneath.

```js
// finalproject.js — mouse listener is scoped to canvas only
canvas.addEventListener("mousemove", (e) => {
  input.x = (e.clientX / window.innerWidth) * 2 - 1;
  input.y = (-e.clientY / window.innerHeight) * 2 + 1;
});
```

```css
/* finalproject.css — HUD blocks pointer events */
#hud { pointer-events: auto; }
```

This is intentional — it prevents accidental particle attraction/repulsion while clicking HUD buttons.

---

### 5.2 How Mouse Interaction Works

Mouse position is transformed from **CSS pixel coordinates** (top-left origin, y increasing downward) into **Normalized Device Coordinates** (NDC: `[-1, 1]` range, center origin, y increasing upward) to match the WebGPU clip space that the shader uses. The formula divides by window dimensions to get `[0, 1]`, scales to `[-1, 1]`, and flips the y-axis.

```js
// finalproject.js
canvas.addEventListener("mousemove", (e) => {
  input.x = (e.clientX / window.innerWidth) * 2 - 1;   // [0,W] → [-1,1]
  input.y = (-e.clientY / window.innerHeight) * 2 + 1;  // flip Y: [0,H] → [1,-1]
});
```

Left-click sets `clickMode = 1` (attract) and right-click sets `clickMode = 2` (repel). The compute shader checks this value and adds or subtracts a velocity component toward the mouse position each frame.

---

### 5.3 How WebGPU Buffers Work

Three buffer types are used:

| Type | Usage Flags | Used For |
|---|---|---|
| **Storage** | `STORAGE \| COPY_DST` | Particle data (ping-pong pair) — large, read/write by compute shader |
| **Uniform** | `UNIFORM \| COPY_DST` | `InputState` struct — small, read-only in shader, written by CPU each frame |
| *(No staging buffer)* | — | Data is uploaded directly via `device.queue.writeBuffer()` |

Storage buffers hold the per-particle array and can be both read and written by the GPU. The uniform buffer holds the small `InputState` struct (mouse position, simMode, forceStrength, etc.) and is updated each frame with `device.queue.writeBuffer()`. There is no staging/readback buffer because the CPU never needs to read particle data back.

---

### 5.4 How the Compute Pipeline Works

The compute pipeline uses a **workgroup size of 256** — meaning each GPU workgroup processes 256 particles in parallel. The number of workgroups dispatched is `ceil(activeParticleCount / 256)`, so all active particles are covered. Inside `computeMain`, each invocation gets a unique `global_invocation_id.x` as its particle index, reads from the read-only `particlesIn` storage buffer, applies physics, and writes the result to `particlesOut`.

```js
// lib/Scene/FinalProjectParticleSystemObject.js — compute()
pass.dispatchWorkgroups(Math.ceil(this._activeParticleCount / 256));
this._step++;  // flip which buffer is "in" vs "out" next frame
```

```wgsl
// lib/Shaders/finalprojectparticles.wgsl
@compute @workgroup_size(256)
fn computeMain(@builtin(global_invocation_id) gid: vec3u) {
  let idx = gid.x;
  if (idx >= arrayLength(&particlesIn)) { return; }  // bounds check
  var p = particlesIn[idx];
  // ...physics...
  particlesOut[idx] = p;
}
```

---

### 5.5 How the Render Pipeline Works

Rendering uses **vertex instancing**: `pass.draw(6, activeParticleCount)` tells the GPU to run the vertex shader 6 times (two triangles = one quad) for each of the `activeParticleCount` instances. The `@builtin(instance_index)` (`pIdx`) tells the vertex shader which particle to read from the storage buffer, and `@builtin(vertex_index)` (`vIdx`) tells it which of the 6 corners of the quad to compute.

```js
// lib/Scene/FinalProjectParticleSystemObject.js — render()
pass.draw(6, this._activeParticleCount);
// 6 vertices × N instances → N quads drawn in one draw call
```

```wgsl
// lib/Shaders/finalprojectparticles.wgsl — vertexMain
@vertex fn vertexMain(
  @builtin(vertex_index)    vIdx: u32,  // which corner (0-5) of this particle's quad
  @builtin(instance_index)  pIdx: u32   // which particle in the buffer
) -> VertexOut {
  let p = particlesIn[pIdx];            // read this particle's data
  let corner = quadCorner(vIdx);        // get corner offset
  var pos = p.p + corner * halfSize;    // compute world position
  // ...
}
```

---

### 5.6 GitHub Pages Deployment and ES Modules

The project is deployed on **GitHub Pages** directly from the repository — no build step, bundler, or server-side code is needed. The HTML file uses `<script type="module">`, which enables native ES module imports (`import`/`export`) in the browser. GitHub Pages serves static files over HTTPS, which is required for WebGPU (it does not work on plain `http://`).

```html
<!-- finalproject.html -->
<script type="module" src="./finalproject.js"></script>
```

```js
// finalproject.js — native ES module imports
import Renderer from "./lib/Viz/2DRenderer.js";
import FinalProjectParticleSystemObject from "./lib/Scene/FinalProjectParticleSystemObject.js";
import HUDManager from "./hud.js";
```

The browser fetches each module file separately via HTTP — no bundling required. One important constraint: ES modules and WebGPU both require **HTTPS or localhost**, so the project cannot be opened directly from the filesystem (`file://` protocol) — it must be served.

---

*End of technical documentation. Refer to the source files listed in each section for deeper dives.*
