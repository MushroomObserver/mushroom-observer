// app/javascript/controllers/status_light_controller.js
import { Controller } from "@hotwired/stimulus"

// This controller updates the status of a "status light" that shows
// whether an autocompleted input value matches a set of supplied matches.
// The status light messages are translatable, sent as data values from Rails
export default class extends Controller {
  static values = {
    matches: Array,
    messages: { type: Object, default: { off: "", red: "", green: "" } }
  }
  static targets = ["input", "light", "message"]

  connect() {
    this.element.dataset.statusLight = "connected";
    // console.log("Status light controller connected")
    this.validStates = ["off", "red", "green"]
    this.setStatus("off")
  }

  // Private method to get current status
  getStatus() {
    return this.currentStatus
  }

  // Private method to set status programmatically
  setStatus(status) {
    // sanitize publicly sendable value
    if (!this.validStates.includes(status)) return

    this.currentStatus = status
    this.lightTarget.classList.remove("off", "red", "green")
    this.lightTarget.classList.add(status)
    console.log(this.messagesValue[this.currentStatus])
    this.messageTarget.textContent = this.messagesValue[this.currentStatus]
  }

  // Public method to check input against list of matching names
  checkMatch(event) {
    const inputValue = event.target.value.toLowerCase().trim()
    // console.log("Checking match for:", inputValue)

    // If no input, show the "off" message
    if (!inputValue) {
      // console.log("checkMatch: Empty input, setting status 'off'")
      this.setStatus("off")
      return
    }

    // Check if input matches the start of any text_name in the matches
    const hasMatch = this.matchesValue.some(obj =>
      obj.text_name.toLowerCase().startsWith(inputValue)
    )

    const status = hasMatch ? "green" : "red"
    this.setStatus(status)
  }

}
