import { Controller } from "@hotwired/stimulus"

// Debounces (throttles) form auto-submit on input changes.
// Usage:
//   <form data-controller="autosubmit" data-autosubmit-delay-value="500">
//     <input data-action="input->autosubmit#submit">
//   </form>
export default class extends Controller {
  static values = { delay: { type: Number, default: 1000 } }

  connect() {
    this.timeout = null
    this.element.dataset.autosubmitConnected = "true"
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
