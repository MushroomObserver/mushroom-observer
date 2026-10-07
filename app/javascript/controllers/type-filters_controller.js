import { Controller } from "@hotwired/stimulus"

// Stops a checkbox click from reaching document, so Bootstrap's
// dropdown stays open (its own "stay open" exception only covers a
// bare <input>/<textarea> target). Also disables Apply until a
// checkbox's checked state differs from page-load.
export default class extends Controller {
  static targets = ["submit", "submitItem", "checkbox"]

  stop(event) {
    event.stopPropagation()
  }

  checkChanged() {
    const dirty = this.checkboxTargets.some(
      (box) => box.checked !== box.defaultChecked
    )
    this.submitTarget.disabled = !dirty
    this.submitItemTarget.classList.toggle("disabled", !dirty)
  }
}
