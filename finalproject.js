import Renderer from "./lib/Viz/2DRenderer.js";
import FinalProjectParticleSystemObject from "./lib/Scene/FinalProjectParticleSystemObject.js";
import HUDManager from "./hud.js";

const MAX_ACTIVE_PARTICLE_COUNT = 299; // Configurable runtime cap for active particles in the HUD.

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
    trailsEnabled: 0,
    maxActiveParticles: MAX_ACTIVE_PARTICLE_COUNT,
    activeParticleCount: MAX_ACTIVE_PARTICLE_COUNT,
    hudVisible: true,
    resetRequested: false,
  };
  input.resetParticles = () => {
    input.resetRequested = true;
  };
  input.consumeResetRequest = () => {
    const requested = input.resetRequested;
    input.resetRequested = false;
    return requested;
  };

  // Initialize the interactive HUD
  const hudManager = new HUDManager(hud, input);

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
    let changed = false;
    switch (e.key) {
      case "1":
        input.simMode = 1;
        changed = true;
        break;
      case "2":
        input.simMode = 2;
        changed = true;
        break;
      case "3":
        input.simMode = 3;
        changed = true;
        break;
      case "4":
        input.simMode = 4;
        changed = true;
        break;
      case "5":
        input.simMode = 5;
        changed = true;
        break;
      case "ArrowUp":
        input.forceStrength = Math.min(input.forceStrength + 0.0002, 0.01);
        changed = true;
        break;
      case "ArrowDown":
        input.forceStrength = Math.max(input.forceStrength - 0.0002, 0.0002);
        changed = true;
        break;
      case "ArrowRight":
        input.damping = Math.min(input.damping + 0.001, 0.999);
        changed = true;
        break;
      case "ArrowLeft":
        input.damping = Math.max(input.damping - 0.001, 0.96);
        changed = true;
        break;
      case "[":
        input.particleScale = Math.max(input.particleScale - 0.1, 1.0);
        changed = true;
        break;
      case "]":
        input.particleScale = Math.min(input.particleScale + 0.1, 5.0);
        changed = true;
        break;
      case "t":
      case "T":
        input.trailsEnabled = input.trailsEnabled ? 0 : 1;
        changed = true;
        break;
      case "r":
      case "R":
        input.resetParticles();
        changed = true;
        break;
      case "h":
      case "H":
        input.hudVisible = !input.hudVisible;
        changed = true;
        break;
      case "-":
        input.activeParticleCount = Math.max(input.activeParticleCount - 1, 0);
        changed = true;
        break;
      case "+":
      case "=":
        input.activeParticleCount = Math.min(input.activeParticleCount + 1, input.maxActiveParticles);
        changed = true;
        break;
    }

    if (changed) {
      hudManager.refresh();
    }
  });

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
