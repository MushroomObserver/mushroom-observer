import { Controller } from "@hotwired/stimulus"

// Adopt-value dropdowns on the primary observation's notes edit form.
// A row's <select> offers distinct sibling values for its notes key;
// picking one copies it into the row's textarea (the primary adopts it,
// and can then edit it). Two row kinds:
//   - inherited (data-notes-inherited): the primary doesn't own the key.
//     The textarea starts disabled (submits nothing -> stays inherited);
//     adopting enables it, and resetting to blank disables + clears it.
//   - owned: the textarea already holds the primary's value; adopting
//     overwrites it, and resetting to blank is a no-op (keep current).
//
// Connects to data-controller="notes-adopt"
export default class extends Controller {
  connect() {
    this.element.dataset.notesAdopt = "connected"
    // Capture each adopt textarea's pristine value so an owned row can
    // revert to it when the "keep current value" default is reselected.
    this.originals = new Map()
    this.element.querySelectorAll("[data-notes-row] textarea").forEach(
      (textarea) => this.originals.set(textarea, textarea.value)
    )
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
    } else if (row.hasAttribute("data-notes-inherited")) {
      // Un-adopt an inherited row: clear + disable so it stays inherited.
      textarea.value = ""
      textarea.disabled = true
      row.classList.add("text-muted")
    } else {
      // Owned row: restore the primary's original value.
      textarea.value = this.originals.get(textarea) ?? ""
    }
  }
}
