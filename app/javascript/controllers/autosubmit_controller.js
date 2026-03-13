import { Controller } from "@hotwired/stimulus"

// Store pending focus info to survive turbo frame replacement.
// Keyed by turbo frame ID.
const pendingFocus = new Map()

// Debounces (throttles) form auto-submit on input changes.
// Restores focus and value after turbo frame updates.
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

    const input = event.target
    const frameId = this.element.dataset.turboFrame

    if (frameId && (input.tagName === "INPUT" || input.tagName === "TEXTAREA")) {
      // Store input name for lookup in captureInputState
      this.pendingInputName = input.name
      this.pendingFrameId = frameId

      // Listen for frame update to capture state right before replacement
      const frame = document.getElementById(frameId)
      if (frame) {
        frame.addEventListener(
          "turbo:before-frame-render",
          this.captureInputState,
          { once: true }
        )
      }
    }

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  // Arrow function to preserve `this` binding
  captureInputState = () => {
    // Capture current value and cursor right before turbo replaces the frame
    const input = this.element.querySelector(`[name="${this.pendingInputName}"]`)
    if (input) {
      pendingFocus.set(this.pendingFrameId, {
        inputName: this.pendingInputName,
        value: input.value,
        selectionStart: input.selectionStart,
        selectionEnd: input.selectionEnd
      })
    }
  }

  restoreFocus() {
    const frameId = this.element.dataset.turboFrame
    if (!frameId) return

    const focusData = pendingFocus.get(frameId)
    if (!focusData) return

    pendingFocus.delete(frameId)

    const input = this.element.querySelector(`[name="${focusData.inputName}"]`)
    if (input) {
      // Restore value and cursor position
      input.value = focusData.value
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
