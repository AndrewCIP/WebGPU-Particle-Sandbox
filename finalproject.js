import Renderer from "./lib/Viz/2DRenderer.js";
import FinalProjectParticleSystemObject from "./lib/Scene/FinalProjectParticleSystemObject.js";

async function init() {
  const canvas = document.createElement("canvas");
  canvas.id = "renderCanvas";
  document.body.appendChild(canvas);

  const hud = document.createElement("div");
  hud.id = "hud";
  document.body.appendChild(hud);

  const renderer = new Renderer(canvas);
  await renderer.init();

  const particles = new FinalProjectParticleSystemObject(
    renderer._device,
    renderer._canvasFormat,
    "./lib/Shaders/finalprojectparticles.wgsl",
    4096
  );

  await renderer.appendSceneObject(particles);

  const input = {
    x: 0,
    y: 0,
    clickMode: 0,
    simMode: 1,
    forceStrength: 0.002,
    damping: 0.992,
    particleScale: 1.0,
  };

  function getModeName(mode) {
    switch (mode) {
      case 1: return "Static";
      case 2: return "Gravity";
      case 3: return "Explosion";
      case 4: return "Orbit";
      default: return "Unknown";
    }
  }

  function updateHUD() {
    hud.innerHTML = `
      <div><strong>Interactive WebGPU Particle Sandbox</strong></div>
      <div>Mode: ${getModeName(input.simMode)}</div>
      <div>Force Strength: ${input.forceStrength.toFixed(4)}</div>
      <div>Damping: ${input.damping.toFixed(3)}</div>
      <div>Particle Size: ${input.particleScale.toFixed(1)}</div>
      <div style="margin-top:8px;">1 Static | 2 Gravity | 3 Explosion | 4 Orbit</div>
      <div>Left Click Attract | Right Click Repel</div>
      <div>Arrow Up/Down = Force | Arrow Left/Right = Damping</div>
      <div>[ Smaller | ] Bigger</div>
    `;
  }

  canvas.addEventListener("mousemove", (e) => {
    input.x = (e.clientX / window.innerWidth) * 2 - 1;
    input.y = (-e.clientY / window.innerHeight) * 2 + 1;
  });

  canvas.addEventListener("mousedown", (e) => {
    if (e.button === 0) input.clickMode = 1;
    if (e.button === 2) input.clickMode = 2;
  });

  canvas.addEventListener("mouseup", () => {
    input.clickMode = 0;
  });

  canvas.addEventListener("mouseleave", () => {
    input.clickMode = 0;
  });

  canvas.addEventListener("contextmenu", (e) => {
    e.preventDefault();
  });

  window.addEventListener("keydown", (e) => {
    switch (e.key) {
      case "1":
        input.simMode = 1;
        break;
      case "2":
        input.simMode = 2;
        break;
      case "3":
        input.simMode = 3;
        break;
      case "4":
        input.simMode = 4;
        break;
      case "ArrowUp":
        input.forceStrength = Math.min(input.forceStrength + 0.0002, 0.01);
        break;
      case "ArrowDown":
        input.forceStrength = Math.max(input.forceStrength - 0.0002, 0.0002);
        break;
      case "ArrowRight":
        input.damping = Math.min(input.damping + 0.001, 0.999);
        break;
      case "ArrowLeft":
        input.damping = Math.max(input.damping - 0.001, 0.960);
        break;
      case "[":
        input.particleScale = Math.max(input.particleScale - 0.1, 1.0);
        break;
      case "]":
        input.particleScale = Math.min(input.particleScale + 0.1, 10.0);
        break;
    }

    updateHUD();
  });

  updateHUD();

  function loop() {
    particles.updateInput(input);
    renderer.render();
    requestAnimationFrame(loop);
  }

  loop();
}

init().catch((e) => {
  const p = document.createElement("p");
  p.innerHTML = navigator.userAgent + "<br/>" + e.message;
  document.body.appendChild(p);
});