import { Controller } from "@hotwired/stimulus"

// Couples Include checkboxes and Primary radios on the occurrence
// edit form:
// - Selecting Primary auto-checks Include
// - Unchecking Include on the Primary obs reassigns Primary
export default class extends Controller {
  includeToggled(event) {
    const checkbox = event.currentTarget
    if (checkbox.checked) return

    const radio = this.#findRadio(checkbox)
    if (radio && radio.checked) {
      radio.checked = false
      this.#selectFirstIncludedPrimary()
    }
  }

  primarySelected(event) {
    const radio = event.currentTarget
    const checkbox = this.#findCheckbox(radio)
    if (checkbox && !checkbox.checked) checkbox.checked = true
  }

  // -- private helpers --

  #selectFirstIncludedPrimary() {
    const items = this.element.querySelectorAll("li")
    for (const item of items) {
      const cb = item.querySelector("input[name='observation_ids[]']")
      const radio = item.querySelector("input[type='radio']")
      if (cb?.checked && radio) {
        radio.checked = true
        return
      }
    }
  }

  #findRadio(element) {
    return element.closest("li")?.querySelector(
      "input[type='radio'][name='occurrence[primary_observation_id]']"
    )
  }

  #findCheckbox(element) {
    return element.closest("li")?.querySelector(
      "input[name='observation_ids[]']"
    )
  }
}
