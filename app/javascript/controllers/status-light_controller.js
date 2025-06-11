// app/javascript/controllers/status_light_controller.js
import { Controller } from "@hotwired/stimulus"

// This controller simply updates the status of a "status light", showing
// whether an input value (possibly autocompleted) matches a set of data.
// A separate Stimulus controller checks for the match using the dataset
// sent to that controller. The first of these is "project-search".
export default class extends Controller {
  // These messages are translatable, and sent as data values from Rails
  static values = {
    messages: { type: Object, default: { off: "", red: "", green: "" } }
  }
  static targets = ["light", "message"]

  connect() {
    this.element.dataset.statusLight = "connected";
    // console.log("Status light controller connected")
    this.validStates = ["off", "red", "green"]
    this.setStatus("off")
  }

  // Public method to get current status
  getStatus() {
    return this.currentStatus
  }

  // Public method to set status programmatically
  setStatus(status) {
    // sanity check publicly sendable value
    if (!this.validStates.includes(status)) return

    this.currentStatus = status
    this.lightTarget.classList.remove("off", "red", "green")
    this.lightTarget.classList.add(status)
    console.log(this.messagesValue[this.currentStatus])
    this.messageTarget.textContent = this.messagesValue[this.currentStatus]
  }

  // Callback for externally emitted event "hasMatch",
  // fired from the project-search or another Stimulus controller
  // that determines if the input matches some set of data
  hasMatch(event) {
    const status = event.detail.status
    this.setStatus(status)
  }
}
