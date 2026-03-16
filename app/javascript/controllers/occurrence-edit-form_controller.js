import { Controller } from "@hotwired/stimulus"

// Couples Primary radios, Remove checkboxes, and Add checkboxes
// on the occurrence edit form:
// - Checking Remove on the Primary obs reassigns Primary
// - Clicking Primary on a candidate auto-checks Add
// - Clicking Primary on a removed obs unchecks Remove
// - Unchecking Add on the Primary candidate reassigns Primary
// - Create Observation button enabled only when primary is not editable
export default class extends Controller {
  static targets = ["createObsButton"]

  removeToggled(event) {
    const checkbox = event.currentTarget
    if (!checkbox.checked) return

    const radio = this.#findRadio(checkbox)
    if (radio && radio.checked) this.#reassignPrimary()
  }

  addToggled(event) {
    const checkbox = event.currentTarget
    if (checkbox.checked) return

    const radio = this.#findRadio(checkbox)
    if (radio && radio.checked) this.#reassignPrimary()
  }

  primarySelected(event) {
    const radio = event.currentTarget
    const li = radio.closest("li")
    if (!li) return

    const addCheckbox = li.querySelector(
      "input[name='add_observation_ids[]']"
    )
    if (addCheckbox && !addCheckbox.checked) {
      addCheckbox.checked = true
    }

    const removeCheckbox = li.querySelector(
      "input[name='remove_observation_ids[]']"
    )
    if (removeCheckbox && removeCheckbox.checked) {
      removeCheckbox.checked = false
    }

    this.#toggleCreateButton(radio)
  }

  // -- private helpers --

  #reassignPrimary() {
    const radios = this.element.querySelectorAll(
      "input[type='radio'][name='occurrence[primary_observation_id]']"
    )
    const eligible = Array.from(radios).filter((r) => {
      const li = r.closest("li")
      if (!li) return false

      const remove = li.querySelector(
        "input[name='remove_observation_ids[]']"
      )
      if (remove && remove.checked) return false

      const add = li.querySelector("input[name='add_observation_ids[]']")
      if (add && !add.checked) return false

      return true
    })

    const target = eligible[0] || radios[0]
    if (target) {
      target.checked = true
      this.#toggleCreateButton(target)
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
}
