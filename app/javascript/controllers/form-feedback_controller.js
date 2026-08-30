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
    // "Is this thing on?" marker -- same convention as
    // field-slip-job_controller, for inspecting whether Stimulus
    // actually connected on a live page.
    this.element.dataset.formFeedback = "connected";
    this.submitted = this.submitted.bind(this)
    this.element.addEventListener("submit", this.submitted)
    // Non-Turbo submission navigates away, so a real browser Back
    // restores this page from bfcache -- a frozen snapshot taken
    // after disableButtons() already ran. Nothing else re-enables
    // the button on that restore, so it's stuck disabled/spinning.
    this.restoreOnPageshow = this.restoreOnPageshow.bind(this)
    window.addEventListener("pageshow", this.restoreOnPageshow)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.submitted)
    window.removeEventListener("pageshow", this.restoreOnPageshow)
  }

  submitted() {
    if (this.element.dataset.turbo === "true") return

    // Deferred so the clicked button's name/value is serialized into
    // the request before the button is disabled.
    setTimeout(() => this.disableButtons(), 0)
  }

  restoreOnPageshow(event) {
    if (event.persisted) this.restoreButtons()
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
        const original = button.tagName === "BUTTON" ?
          button.textContent : button.value
        button.dataset.originalLabel = original
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

  restoreButtons() {
    const buttons = this.element.querySelectorAll(
      "button[type=submit], input[type=submit]"
    )
    buttons.forEach((button) => {
      if (!button.disabled) return

      button.disabled = false
      const original = button.dataset.originalLabel
      if (original !== undefined) {
        if (button.tagName === "BUTTON") {
          button.textContent = original
        } else {
          button.value = original
        }
        delete button.dataset.originalLabel
      }
      const spinner = button.querySelector(".spinner-right")
      if (spinner) spinner.remove()
    })
  }
}
