// app/javascript/controllers/search-status_controller.js
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
    this.element.dataset.searchStatus = "connected";
    // console.log("search-status controller connected")
    this.validStates = ["off", "red", "green"]
    this.setOffStatus()
  }

  // Private method to get current status
  getStatus() {
    return this.currentStatus
  }

  // Public method to check input against list of matching names
  checkMatch(event) {
    const inputValue = event.target.value.toLowerCase().trim()
    // console.log("Checking match for:", inputValue)

    // If no input, show the "off" message
    if (!inputValue) {
      // console.log("checkMatch: Empty input, setting status 'off'")
      this.setOffStatus()
      return
    }

    // Check if input matches the start of any text_name in the matches
    const hasMatch = this.matchesValue.some(obj =>
      obj.text_name.toLowerCase().startsWith(inputValue)
    )
    const matchingValues = this.matchesValue.filter(obj =>
      obj.text_name.toLowerCase().startsWith(inputValue)
    )
    this.setStatus(matchingValues)
  }

  // Low-level function with common functionality
  _updateDisplay(status, textContent) {
    // sanitize publicly sendable value
    if (!this.validStates.includes(status)) return

    this.currentStatus = status
    this.lightTarget.classList.remove("off", "red", "green")
    this.lightTarget.classList.add(status)
    // console.log(this.messagesValue[this.currentStatus])
    this.messageTarget.textContent = textContent
  }

  // Function that only sets red or green based on values list
  setStatus(values) {
    let status, textContent;

    if (values.length === 0) {
      status = "red";
      textContent = this.messagesValue[status];
    } else {
      status = "green";
      const baseMessage = this.messagesValue[status];
      if (values.length === 1) {
        textContent = `${baseMessage} ${values[0].text_name || values[0]}`;
      } else {
        textContent = `${baseMessage} ${values[0].text_name || values[0]}, ...`;
      }
    }

    this._updateDisplay(status, textContent);
  }

  // Function that handles the "off" case
  setOffStatus() {
    const status = "off";
    const textContent = this.messagesValue[status];
    this._updateDisplay(status, textContent);
  }
}
