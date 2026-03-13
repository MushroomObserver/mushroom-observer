import { Controller } from "@hotwired/stimulus"

// Couples Primary radios, Remove checkboxes, and Add checkboxes
// on the occurrence edit form:
// - Checking Remove on the Primary obs reassigns Primary
// - Clicking Primary on a candidate auto-checks Add
// - Clicking Primary on a removed obs unchecks Remove
// - Unchecking Add on the Primary candidate reassigns Primary
export default class extends Controller {
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
      return
    }

    const removeCheckbox = li.querySelector(
      "input[name='remove_observation_ids[]']"
    )
    if (removeCheckbox && removeCheckbox.checked) {
      removeCheckbox.checked = false
    }
  }

  // -- private helpers --

  #reassignPrimary() {
    const radios = this.element.querySelectorAll(
      "input[type='radio'][name='occurrence[default_observation_id]']"
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
    if (target) target.checked = true
  }

  #findRadio(element) {
    return element.closest("li")?.querySelector(
      "input[type='radio'][name='occurrence[default_observation_id]']"
    )
  }
}
