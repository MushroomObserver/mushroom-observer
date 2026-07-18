import { Controller } from "@hotwired/stimulus"

// Adopt-value dropdowns on the primary observation's notes edit form.
// Each inherited (gray) row has a <select> of the distinct sibling
// values and a disabled textarea named `observation[notes][<key>]`.
// Picking a value fills + enables the textarea so it submits (the
// primary adopts the value, and can then edit it); resetting to the
// blank default disables it again so nothing submits and the value
// stays inherited via the display-time merge.
//
// Connects to data-controller="notes-adopt"
export default class extends Controller {
  connect() {
    this.element.dataset.notesAdopt = "connected"
  }

  adopt(event) {
    const row = event.target.closest("[data-notes-row]")
    if (!row) return
    const textarea = row.querySelector("textarea")
    if (!textarea) return

    const value = event.target.value
    if (value) {
      textarea.value = value
      textarea.disabled = false
      row.classList.remove("text-muted")
    } else {
      textarea.value = ""
      textarea.disabled = true
      row.classList.add("text-muted")
    }
  }
}
