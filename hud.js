// hud.js

class HUD {
    constructor() {
        this.modes = ['static', 'gravity', 'explosion', 'orbit'];
        this.controls = {
            forceStrength: 1,
            damping: 0.1,
            particleSize: 5,
            trails: false
        };
        this.activeMode = null;
        this.init();
    }
    
    init() {
        this.createButtons();
        this.createControls();
        this.addEventListeners();
    }
    
    createButtons() {
        const modeContainer = document.createElement('div');
        this.modes.forEach(mode => {
            const button = document.createElement('button');
            button.innerText = mode;
            button.className = 'hud-button';
            button.addEventListener('click', () => this.setMode(mode));
            modeContainer.appendChild(button);
        });
        document.body.appendChild(modeContainer);
    }
    
    createControls() {
        const controlContainer = document.createElement('div');
        Object.keys(this.controls).forEach(control => {
            const label = document.createElement('label');
            label.innerText = control;
            const input = document.createElement('input');
            input.type = control === 'trails' ? 'checkbox' : 'range';
            input.value = this.controls[control];
            input.addEventListener('input', (e) => this.updateControl(control, e.target.value));
            label.appendChild(input);
            controlContainer.appendChild(label);
        });
        document.body.appendChild(controlContainer);
    }
    
    setMode(mode) {
        this.activeMode = mode;
        console.log(`Mode set to: ${mode}`);
    }
    
    updateControl(control, value) {
        if (control === 'trails') {
            this.controls[control] = value === 'true';
        } else {
            this.controls[control] = parseFloat(value);
        }
        console.log(`${control} updated to: ${this.controls[control]}`);
    }
    
    addEventListeners() {
        document.addEventListener('mousemove', (e) => this.onMouseMove(e));
        document.addEventListener('keydown', (e) => this.onKeyDown(e));
    }
    
    onMouseMove(e) {
        // Handle mouse hover highlighting
    }
    
    onKeyDown(e) {
        // Handle keyboard interaction
    }
}

const hud = new HUD();