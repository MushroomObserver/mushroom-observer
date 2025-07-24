import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="page-input"
// Sanitizes the page number to min/max values
export default class extends Controller {
  static targets = ["input"]
  static values = { max: Number }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.pageInput = "connected"
  }

  // When the input changes, sanitize the value of the input.
  // Since this action is fired onInput, before the browser has changed the
  // value attribute, also "manually" set the value *attribute*.
  updateForm() {
    let pageInput = parseInt(this.inputTarget.value || 1)
    if (pageInput > this.maxValue) { pageInput = this.maxValue }
    this.inputTarget.value = pageInput
    this.inputTarget.setAttribute("value", pageInput)
  }
}
