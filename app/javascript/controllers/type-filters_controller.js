import { Controller } from "@hotwired/stimulus"

// "stop" is a no-op target for the :stop action modifier (keeps
// Bootstrap's dropdown open on a checkbox click). Disables Apply
// until a checkbox's checked state differs from page-load.
export default class extends Controller {
  static targets = ["submit", "submitItem", "checkbox"]

  stop() {}

  checkChanged() {
    const dirty = this.checkboxTargets.some(
      (box) => box.checked !== box.defaultChecked
    )
    this.submitTarget.disabled = !dirty
    this.submitItemTarget.classList.toggle("disabled", !dirty)
  }
}
