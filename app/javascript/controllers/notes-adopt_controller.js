import { Controller } from "@hotwired/stimulus"

// Value-source dropdowns on the primary observation's notes edit form.
// A row's <select> picks what this observation shows for a notes key
// shared with the occurrence's other observations, and drives the row's
// textarea. Each option carries a data-notes-action:
//   - "current": restore the primary's own pristine value (enabled).
//   - "inherit": clear + disable the textarea so it submits nothing and
//     the value stays inherited via the display-time merge.
//   - "hide":    clear but keep enabled, so a blank submits and the
//     display merge suppresses the inherited value.
//   - "adopt" (any sibling value): copy that value in (enabled), which
//     the primary can then edit.
//
// Connects to data-controller="notes-adopt"
export default class extends Controller {
  connect() {
    this.element.dataset.notesAdopt = "connected"
    // Capture each row textarea's pristine value so "Current value" can
    // restore it after the user has previewed other options.
    this.originals = new Map()
    this.element.querySelectorAll("[data-notes-row] textarea").forEach(
      (textarea) => this.originals.set(textarea, textarea.value)
    )
  }

  adopt(event) {
    const option = event.target.selectedOptions[0]
    const row = event.target.closest("[data-notes-row]")
    if (!row) return
    const textarea = row.querySelector("textarea")
    if (!textarea) return

    switch (option.dataset.notesAction) {
      case "inherit":
        this.setRow(row, textarea, "", true)
        break
      case "hide":
        this.setRow(row, textarea, "", false)
        break
      case "current":
        this.setRow(row, textarea, this.originals.get(textarea) ?? "", false)
        break
      default: // "adopt": a specific sibling value
        this.setRow(row, textarea, option.value, false)
    }
  }

  setRow(row, textarea, value, disabled) {
    textarea.value = value
    textarea.disabled = disabled
    row.classList.toggle("text-muted", disabled)
  }
}
