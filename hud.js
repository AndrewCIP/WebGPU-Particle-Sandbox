// HUD Button Management System

class HUDButton {
  constructor(id, label, callback, group = null) {
    this.id = id;
    this.label = label;
    this.callback = callback;
    this.group = group;
    this.active = false;
    this.element = null;
  }

  create() {
    this.element = document.createElement("button");
    this.element.id = this.id;
    this.element.className = "hud-button";
    if (this.group) {
      this.element.classList.add(`group-${this.group}`);
    }
    this.element.textContent = this.label;
    this.element.addEventListener("click", (e) => {
      e.stopPropagation();
      this.callback();
    });
    this.element.addEventListener("mouseenter", () => {
      this.element.classList.add("hover");
    });
    this.element.addEventListener("mouseleave", () => {
      this.element.classList.remove("hover");
    });
    return this.element;
  }

  setActive(active) {
    this.active = active;
    if (this.element) {
      if (active) {
        this.element.classList.add("active");
      } else {
        this.element.classList.remove("active");
      }
    }
  }
}

class HUDManager {
  constructor(hudElement, input) {
    this.hudElement = hudElement;
    this.input = input;
    this.buttons = {};
    this.modeButtons = {};
    this.updateHUD();
  }

  updateHUD() {
    this.hudElement.innerHTML = "";
    this.buttons = {};
    this.modeButtons = {};

    const title = document.createElement("div");
    title.className = "hud-title";
    title.innerHTML = "<strong>Interactive WebGPU Particle Sandbox</strong>";
    this.hudElement.appendChild(title);

    this.createModeSection();
    this.createControlSection();
    this.createInfoSection();
  }

  createModeSection() {
    const section = document.createElement("div");
    section.className = "hud-section";

    const header = document.createElement("div");
    header.className = "hud-section-header";
    header.textContent = "MODES";
    section.appendChild(header);

    const modes = [
      { id: "mode-1", label: "1: Static", value: 1 },
      { id: "mode-2", label: "2: Gravity", value: 2 },
      { id: "mode-3", label: "3: Explosion", value: 3 },
      { id: "mode-4", label: "4: Orbit", value: 4 },
    ];

    const buttonContainer = document.createElement("div");
    buttonContainer.className = "hud-button-row";

    modes.forEach((mode) => {
      const btn = new HUDButton(
        mode.id,
        mode.label,
        () => {
          this.input.simMode = mode.value;
          this.updateModeHighlight();
        },
        "modes"
      );
      this.modeButtons[mode.value] = btn;
      this.buttons[mode.id] = btn;
      buttonContainer.appendChild(btn.create());
    });

    section.appendChild(buttonContainer);
    this.hudElement.appendChild(section);
    this.updateModeHighlight();
  }

  updateModeHighlight() {
    Object.entries(this.modeButtons).forEach(([value, btn]) => {
      btn.setActive(this.input.simMode === parseInt(value));
    });
  }

  createControlSection() {
    const section = document.createElement("div");
    section.className = "hud-section";

    const header = document.createElement("div");
    header.className = "hud-section-header";
    header.textContent = "CONTROLS";
    section.appendChild(header);

    // Force Strength
    const forceRow = document.createElement("div");
    forceRow.className = "hud-control-row";
    forceRow.appendChild(this.createLabel("Force Strength:"));
    forceRow.appendChild(new HUDButton("force-dec", "↓", () => {
      this.input.forceStrength = Math.max(this.input.forceStrength - 0.0002, 0.0002);
      this.updateValues();
    }).create());
    const forceValue = document.createElement("span");
    forceValue.id = "force-value";
    forceValue.className = "hud-value";
    forceValue.textContent = this.input.forceStrength.toFixed(4);
    forceRow.appendChild(forceValue);
    forceRow.appendChild(new HUDButton("force-inc", "↑", () => {
      this.input.forceStrength = Math.min(this.input.forceStrength + 0.0002, 0.01);
      this.updateValues();
    }).create());
    section.appendChild(forceRow);

    // Damping
    const dampingRow = document.createElement("div");
    dampingRow.className = "hud-control-row";
    dampingRow.appendChild(this.createLabel("Damping:"));
    dampingRow.appendChild(new HUDButton("damping-dec", "←", () => {
      this.input.damping = Math.max(this.input.damping - 0.001, 0.96);
      this.updateValues();
    }).create());
    const dampingValue = document.createElement("span");
    dampingValue.id = "damping-value";
    dampingValue.className = "hud-value";
    dampingValue.textContent = this.input.damping.toFixed(3);
    dampingRow.appendChild(dampingValue);
    dampingRow.appendChild(new HUDButton("damping-inc", "→", () => {
      this.input.damping = Math.min(this.input.damping + 0.001, 0.999);
      this.updateValues();
    }).create());
    section.appendChild(dampingRow);

    // Particle Size
    const sizeRow = document.createElement("div");
    sizeRow.className = "hud-control-row";
    sizeRow.appendChild(this.createLabel("Particle Size:"));
    sizeRow.appendChild(new HUDButton("size-dec", "[", () => {
      this.input.particleScale = Math.max(this.input.particleScale - 0.1, 1.0);
      this.updateValues();
    }).create());
    const sizeValue = document.createElement("span");
    sizeValue.id = "size-value";
    sizeValue.className = "hud-value";
    sizeValue.textContent = this.input.particleScale.toFixed(1);
    sizeRow.appendChild(sizeValue);
    sizeRow.appendChild(new HUDButton("size-inc", "]", () => {
      this.input.particleScale = Math.min(this.input.particleScale + 0.1, 5.0);
      this.updateValues();
    }).create());
    section.appendChild(sizeRow);

    // Trails
    const trailsRow = document.createElement("div");
    trailsRow.className = "hud-control-row";
    trailsRow.appendChild(new HUDButton("trails-toggle", "T: Trails OFF", () => {
      this.input.trailsEnabled = this.input.trailsEnabled ? 0 : 1;
      this.updateValues();
    }).create());
    section.appendChild(trailsRow);

    this.hudElement.appendChild(section);
  }

  createLabel(text) {
    const label = document.createElement("span");
    label.className = "hud-label";
    label.textContent = text;
    return label;
  }

  createInfoSection() {
    const section = document.createElement("div");
    section.className = "hud-section hud-info";
    const info = document.createElement("div");
    info.innerHTML = `<small><strong>Mouse:</strong> Left Click = Attract | Right Click = Repel<br/><strong>Keyboard:</strong> 1-4 = Modes | ↑↓ = Force | ←→ = Damping<br/><strong>Size:</strong> [ Smaller | ] Bigger | T = Trails</small>`;
    section.appendChild(info);
    this.hudElement.appendChild(section);
  }

  updateValues() {
    const forceValue = document.getElementById("force-value");
    const dampingValue = document.getElementById("damping-value");
    const sizeValue = document.getElementById("size-value");
    const trailsBtn = document.getElementById("trails-toggle");

    if (forceValue) forceValue.textContent = this.input.forceStrength.toFixed(4);
    if (dampingValue) dampingValue.textContent = this.input.damping.toFixed(3);
    if (sizeValue) sizeValue.textContent = this.input.particleScale.toFixed(1);
    if (trailsBtn) trailsBtn.textContent = `T: Trails ${this.input.trailsEnabled ? "ON" : "OFF"}`;
    this.updateModeHighlight();
  }

  refresh() {
    this.updateValues();
  }
}

export default HUDManager;
