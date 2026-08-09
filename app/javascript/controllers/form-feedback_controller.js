import { Controller } from "@hotwired/stimulus"

// Disables a form's submit buttons once it is submitted, swapping in
// their data-disable-with label and a spinner -- immediate feedback
// that the click took, and no double-submits from clicking again while
// the request runs. rails-ujs used to own this behavior and is turned
// off; Turbo forms handle their own in-flight state, so they are
// skipped here.
// Connects to data-controller="form-feedback" (every ApplicationForm)
export default class extends Controller {
  connect() {
    this.element.dataset.formFeedback = "connected";
    this.submitted = this.submitted.bind(this)
    this.element.addEventListener("submit", this.submitted)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.submitted)
  }

  submitted() {
    if (this.element.dataset.turbo === "true") return

    // Deferred so the clicked button's name/value is serialized into
    // the request before the button is disabled.
    setTimeout(() => this.disableButtons(), 0)
  }

  disableButtons() {
    const buttons = this.element.querySelectorAll(
      "button[type=submit], input[type=submit]"
    )
    buttons.forEach((button) => {
      if (button.disabled) return

      button.disabled = true
      const label = button.dataset.disableWith
      if (label) {
        if (button.tagName === "BUTTON") {
          button.textContent = label
        } else {
          button.value = label
        }
      }
      if (button.tagName === "BUTTON") {
        const spinner = document.createElement("span")
        spinner.className = "spinner-right mx-2"
        button.appendChild(spinner)
      }
    })
  }
}
