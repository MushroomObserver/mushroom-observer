import { Controller } from "@hotwired/stimulus"

// Couples "Include" checkboxes and "Primary" radio buttons:
// - Selecting "Primary" auto-checks "Include"
// - Unchecking "Include" clears "Primary" (reverts to source)
export default class extends Controller {
  static targets = ["sourceRadio"]

  primarySelected(event) {
    const radio = event.currentTarget
    const checkbox = this.#findCheckbox(radio)
    if (checkbox && !checkbox.checked) checkbox.checked = true
  }

  includeToggled(event) {
    const checkbox = event.currentTarget
    if (checkbox.checked) return

    const radio = this.#findRadio(checkbox)
    if (radio && radio.checked) {
      radio.checked = false
      this.sourceRadioTarget.checked = true
    }
  }

  // -- private helpers --

  #findCheckbox(radio) {
    return radio.closest("li")?.querySelector("input[type='checkbox']")
  }

  #findRadio(checkbox) {
    return checkbox.closest("li")?.querySelector("input[type='radio']")
  }
}
