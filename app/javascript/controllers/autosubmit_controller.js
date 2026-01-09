import { Controller } from "@hotwired/stimulus"

// Store pending focus info to survive turbo frame replacement.
// Keyed by turbo frame ID.
const pendingFocus = new Map()

// Debounces (throttles) form auto-submit on input changes.
// Restores focus after turbo frame updates.
// Usage:
//   <form data-controller="autosubmit" data-autosubmit-delay-value="500"
//         data-turbo-frame="my_frame">
//     <input data-action="input->autosubmit#submit">
//   </form>
export default class extends Controller {
  static values = { delay: { type: Number, default: 500 } }

  connect() {
    this.timeout = null
    this.element.dataset.autosubmitConnected = "true"

    // Restore focus after turbo frame update replaced the form
    this.restoreFocus()
  }

  submit(event) {
    clearTimeout(this.timeout)

    // Store focus info for restoration after turbo frame update
    const input = event.target
    const frameId = this.element.dataset.turboFrame

    if (frameId && (input.tagName === "INPUT" || input.tagName === "TEXTAREA")) {
      pendingFocus.set(frameId, {
        inputName: input.name,
        selectionStart: input.selectionStart,
        selectionEnd: input.selectionEnd
      })
    }

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  restoreFocus() {
    const frameId = this.element.dataset.turboFrame
    if (!frameId) return

    const focusData = pendingFocus.get(frameId)
    if (!focusData) return

    // Clear pending focus
    pendingFocus.delete(frameId)

    // Find and focus the input, restoring cursor position
    const input = this.element.querySelector(`[name="${focusData.inputName}"]`)
    if (input) {
      input.focus()
      if (typeof input.setSelectionRange === "function") {
        input.setSelectionRange(focusData.selectionStart, focusData.selectionEnd)
      }
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
