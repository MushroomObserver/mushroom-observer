import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="page-input"
// Sanitizes the page number to min/max values
export default class extends Controller {
  static targets = ["numberInput", "letterInput"]
  static values = { max: Number, letters: String }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.pageInput = "connected"
  }

  // When page number input changes, sanitize the value of the input.
  // Since this action is fired onInput, before the browser has changed the
  // value attribute, also "manually" set the value *attribute*.
  sanitizeNumber() {
    let numberInput = parseInt(this.numberInputTarget.value || 1)
    if (numberInput > this.maxValue) { numberInput = this.maxValue }
    this.numberInputTarget.value = numberInput
    this.numberInputTarget.setAttribute("value", numberInput)
  }

  // When letter input changes, make it a letter or a dash.
  // If dash, clear the input value attribute.
  sanitizeLetter() {
    let letterInput = this.letterInputTarget.value.toUpperCase() || ""
    if (!this.isLetter(letterInput)) letterInput = ""

    this.letterInputTarget.value = letterInput
    // if (letterInput == "") {
    this.letterInputTarget.setAttribute("value", letterInput)
    // }
  }

  isLetter(char) {
    return /^[a-zA-Z]$/.test(char)
  }
}
