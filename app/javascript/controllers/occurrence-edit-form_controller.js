import { Controller } from "@hotwired/stimulus"

// Couples Include checkboxes and Primary radios on the occurrence
// edit form:
// - Selecting Primary auto-checks Include
// - Unchecking Include on the Primary obs reassigns Primary
// - Create Observation button enabled only when primary is not editable
export default class extends Controller {
  static targets = ["createObsButton"]

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

    this.#toggleCreateButton(radio)
  }

  // -- private helpers --

  #selectFirstIncludedPrimary() {
    const items = this.element.querySelectorAll("li")
    for (const item of items) {
      const cb = item.querySelector("input[name='observation_ids[]']")
      const radio = item.querySelector("input[type='radio']")
      if (cb?.checked && radio) {
        radio.checked = true
        this.#toggleCreateButton(radio)
        return
      }
    }
  }

  #toggleCreateButton(radio) {
    if (!this.hasCreateObsButtonTarget) return

    const editable = radio.dataset.editable === "true"
    this.createObsButtonTarget.disabled = editable
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
