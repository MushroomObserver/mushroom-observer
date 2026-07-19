import { Controller } from "@hotwired/stimulus"

// Value-source buttons on the primary observation's notes edit form. For
// a notes key shared with the occurrence's other observations, each
// button either copies a specific value into the textarea (its own or a
// sibling's, carried in data-notes-value) or applies an action:
//   - "current"/"adopt": copy that value in (editable).
//   - "inherit": show the inherited value (from the row) + disable, so it
//     submits nothing and the value stays inherited via the display-time
//     merge -- greyed so you can see what will display.
//   - "hide": clear + make readonly (not disabled), so a blank still
//     submits (suppressing the inherited value) but can't be typed into.
//   - "concatenate": join all distinct values (own + siblings) into one.
// The clicked button is marked active so the current state -- Inherit vs
// Hide in particular -- stays visible when the textarea is empty.
//
// Connects to data-controller="notes-adopt"
export default class extends Controller {
  choose(event) {
    const button = event.currentTarget
    const row = button.closest("[data-notes-row]")
    if (!row) return
    const textarea = row.querySelector("textarea")
    if (!textarea) return

    switch (button.dataset.notesAction) {
      case "inherit":
        this.setRow(row, textarea, {
          value: row.dataset.notesInheritedValue || "",
          disabled: true,
        })
        break
      case "hide":
        this.setRow(row, textarea, { value: "", readOnly: true })
        break
      case "concatenate":
        this.setRow(row, textarea, { value: this.concatenatedValue(row) })
        break
      default: // "current" or "adopt": copy the button's value
        this.setRow(row, textarea, { value: button.dataset.notesValue })
    }
    this.setActive(row, button)
  }

  setRow(row, textarea, { value, disabled = false, readOnly = false }) {
    textarea.value = value
    textarea.disabled = disabled
    textarea.readOnly = readOnly
    row.classList.toggle("text-muted", disabled || readOnly)
  }

  setActive(row, button) {
    row
      .querySelectorAll("[data-notes-action]")
      .forEach((b) => b.classList.remove("active"))
    button.classList.add("active")
  }

  // All distinct non-blank values for this key -- the primary's own plus
  // each sibling's (the value buttons carry them) -- joined one per line.
  concatenatedValue(row) {
    const values = []
    row
      .querySelectorAll("[data-notes-value]")
      .forEach((b) => values.push(b.dataset.notesValue))
    const distinct = [...new Set(values.map((v) => v.trim()).filter(Boolean))]
    return distinct.join("\n")
  }
}
