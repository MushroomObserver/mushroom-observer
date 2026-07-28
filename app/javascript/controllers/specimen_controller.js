import { Controller } from "@hotwired/stimulus"

// Keeps "Specimen Available" in sync with the fields that imply a
// specimen exists.
//
// Typing a field slip code into an empty box checks it: a field slip
// almost always means there is a physical specimen, and users kept missing
// the checkbox. That matters more than it looks -- observations#create
// discards the collection number and herbarium record entirely when the
// box is unchecked. Entering a collection number or accession number does
// the same thing.
//
// An explicit uncheck sticks. Once the user unchecks the box while the
// code has content, editing that text won't re-check it; only clearing the
// code and typing a fresh one re-arms the behavior.
export default class extends Controller {
  static targets = ["code", "checkbox", "fields"]

  connect() {
    // A code already in the box on load (a QR scan) had the checkbox set
    // server-side, so the first keystroke must not undo a deliberate
    // uncheck. An empty box means nothing has claimed the checkbox yet.
    this.armed = this.codeIsBlank()
  }

  // On the field slip code input.
  codeChanged() {
    if (this.codeIsBlank()) this.armed = true
    else this.checkCheckbox()
  }

  // On the collection number and accession number inputs.
  checkCheckbox() {
    if (!this.armed || !this.hasCheckboxTarget) return

    // Disarm either way: one automatic check per blanking of the code, so
    // whatever the user decides about the box next is theirs to keep.
    this.armed = false
    if (this.checkboxTarget.checked) return

    this.checkboxTarget.checked = true
    this.showFields()
  }

  // On the checkbox itself, so a manual uncheck disarms the automation.
  checkboxChanged() {
    if (!this.hasCheckboxTarget) return

    this.armed = this.checkboxTarget.checked
  }

  // CheckboxCollapse puts Bootstrap's data-toggle on the <label>, not the
  // <input>, so setting `checked` in JS doesn't open the section.
  showFields() {
    if (this.hasFieldsTarget) $(this.fieldsTarget).collapse("show")
  }

  codeIsBlank() {
    return !this.hasCodeTarget || this.codeTarget.value.trim() === ""
  }
}
