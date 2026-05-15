import { Controller } from "@hotwired/stimulus"

// Couples Include checkboxes and Primary radios in an occurrence matrix
// to maintain the invariant: "the primary observation is always included".
//
// Used by both the create form (OccurrenceForm) and the edit form
// (OccurrenceEditForm); the only behavioral difference between them is the
// fallback strategy when the current primary's Include is unchecked,
// chosen via the `fallback` value.
//
// Actions:
//   primarySelected(event) — fired on a Primary radio click. Auto-checks
//                            the Include checkbox in the same <li>.
//   includeToggled(event)  — fired on an Include checkbox change. If the
//                            checkbox is now unchecked and its <li>'s
//                            Primary radio was the current primary,
//                            demote the radio and reassign Primary via
//                            the configured fallback.
//
// Values:
//   fallback (String):
//     "source"         — switch Primary back to the sourceRadio target.
//                        Intended for the create form, where the seed
//                        observation is always a valid anchor.
//     "first-included" — scan rows in document order and pick the first
//                        observation whose Include is still checked.
//                        Intended for the edit form, which has no anchor.
//                        Default.
//
// Selectors are deliberately name-agnostic (`input[type='checkbox']`,
// `input[type='radio']`) so future param-name changes don't silently
// break this controller — an earlier name-filtered version of the edit
// controller broke when the field was namespaced to
// `occurrence[observation_ids][]`.
export default class extends Controller {
  static targets = ["sourceRadio"]
  static values = { fallback: { type: String, default: "first-included" } }

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
      this.#reassignPrimary()
    }
  }

  // -- private helpers --

  #reassignPrimary() {
    if (this.fallbackValue === "source" && this.hasSourceRadioTarget) {
      this.sourceRadioTarget.checked = true
      return
    }
    this.#selectFirstIncludedPrimary()
  }

  #selectFirstIncludedPrimary() {
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

  #findCheckbox(element) {
    return element.closest("li")?.querySelector("input[type='checkbox']")
  }

  #findRadio(element) {
    return element.closest("li")?.querySelector("input[type='radio']")
  }
}
