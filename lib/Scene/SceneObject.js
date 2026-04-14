/*
 * Copyright (c) 2026 Sing Chun LEE @ Bucknell University. CC BY-NC 4.0.
 * 
 * This code is provided mainly for educational purposes at University of the Pacific.
 *
 * This code is licensed under the Creative Commons Attribution-NonCommercial 4.0
 * International License. To view a copy of the license, visit 
 *   https://creativecommons.org/licenses/by-nc/4.0/
 * or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
 *
 * You are free to:
 *  - Share: copy and redistribute the material in any medium or format.
 *  - Adapt: remix, transform, and build upon the material.
 *
 * Under the following terms:
 *  - Attribution: You must give appropriate credit, provide a link to the license,
 *                 and indicate if changes were made.
 *  - NonCommercial: You may not use the material for commercial purposes.
 *  - No additional restrictions: You may not apply legal terms or technological 
 *                                measures that legally restrict others from doing
 *                                anything the license permits.
 */

export default class SceneObject {
  static _objectCnt = 0;
  constructor(device, canvasFormat, shaderFile) {
    if (this.constructor == SceneObject) {
      throw new Error("Abstract classes can't be instantiated.");
    }
    this._device = device;
    this._canvasFormat = canvasFormat;
    this._shaderFile = shaderFile;
    SceneObject._objectCnt += 1;
  }
  
  getName() {
    return this.constructor.name + " " + SceneObject._objectCnt.toString();
  }
  
  async init() {
    await this.createGeometry();
    await this.createShaders();
    await this.createRenderPipeline();
    await this.createComputePipeline();
  }
  
  async createGeometry() { throw new Error("Method 'createGeometry()' must be implemented."); }
  
  updateGeometry() { }
  
  loadShader(filename) {
    return new Promise((resolve, reject) => {
      const xhttp = new XMLHttpRequest();
      xhttp.open("GET", filename);
      xhttp.setRequestHeader("Cache-Control", "no-cache, no-store, max-age=0");
      xhttp.onload = function() {
        if (xhttp.readyState === XMLHttpRequest.DONE && xhttp.status === 200) {
          resolve(xhttp.responseText);
        }
        else {
          reject({
            status: xhttp.status,
            statusText: xhttp.statusText
          });
        }
      };
      xhttp.onerror = function () {
        reject({
          status: xhttp.status,
          statusText: xhttp.statusText
        });
      };
      xhttp.send();
    });
  }
  
  async createShaders() { 
    let shaderCode = await this.loadShader(this._shaderFile);
    this._shaderModule = this._device.createShaderModule({
      label: " Shader " + this.getName(),
      code: shaderCode,
    }); 
  }
  
  async createRenderPipeline() { throw new Error("Method 'createRenderPipeline()' must be implemented."); }
  
  render(pass) { throw new Error("Method 'render(pass)' must be implemented."); }
  
  async createComputePipeline() { throw new Error("Method 'createComputePipeline()' must be implemented."); }
  
  compute(pass) { throw new Error("Method 'compute(pass)' must be implemented."); }
}