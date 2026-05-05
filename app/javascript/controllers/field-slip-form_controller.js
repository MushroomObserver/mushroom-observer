import { Controller } from "@hotwired/stimulus"

// Couples "Include" checkboxes and "Primary" radio buttons on Field Slip New:
// - Selecting "Primary" auto-checks "Include"
// - Unchecking "Include" clears "Primary"
export default class extends Controller {
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
      this.#selectFirstCheckedPrimary()
    }
  }

  // -- private helpers --

  #findCheckbox(radio) {
    return radio.closest("li")?.querySelector("input[type='checkbox']")
  }

  #findRadio(checkbox) {
    return checkbox.closest("li")?.querySelector("input[type='radio']")
  }

  #selectFirstCheckedPrimary() {
    const items = this.element.querySelectorAll("li")
    for (const item of items) {
      const cb = item.querySelector("input[type='checkbox']")
      const radio = item.querySelector("input[type='radio']")
      if (cb?.checked && radio) {
        radio.checked = true
        return
      }
    }
  }
}
