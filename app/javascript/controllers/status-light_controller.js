// app/javascript/controllers/status_light_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["light", "statusText"]

  connect() {
    this.element.dataset.statusLight = "connected";
    // console.log("Status light controller connected")
    this.currentState = "off"
    this.updateStatus()
  }

  setRed() {
    this.lightTarget.className = "status-indicator red"
    this.currentState = "red"
    this.updateStatus()

    // Dispatch custom event
    this.dispatch("changed", { detail: { state: "red" } })
  }

  setGreen() {
    this.lightTarget.className = "status-indicator green"
    this.currentState = "green"
    this.updateStatus()

    // Dispatch custom event
    this.dispatch("changed", { detail: { state: "green" } })
  }

  toggle() {
    if (this.currentState === "off" || this.currentState === "red") {
      this.setGreen()
    } else {
      this.setRed()
    }
  }

  turnOff() {
    this.lightTarget.className = "status-indicator"
    this.currentState = "off"
    this.updateStatus()

    // Dispatch custom event
    this.dispatch("changed", { detail: { state: "off" } })
  }

  // Public method to get current state
  getState() {
    return this.currentState
  }

  // Public method to set state programmatically
  setState(state) {
    switch(state) {
      case "red":
        this.setRed()
        break
      case "green":
        this.setGreen()
        break
      case "off":
        this.turnOff()
        break
    }
  }

  // Private method
  updateStatus() {
    const statusText = this.currentState.charAt(0).toUpperCase() + this.currentState.slice(1)
    this.statusTextTarget.textContent = statusText
  }

  // Example of responding to external events
  handleExternalEvent(event) {
    // You can call this from other controllers or JavaScript
    const { condition } = event.detail

    if (condition === "success") {
      this.setGreen()
    } else if (condition === "error") {
      this.setRed()
    } else {
      this.turnOff()
    }
  }
}
