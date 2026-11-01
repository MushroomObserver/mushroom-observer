import { Controller } from "@hotwired/stimulus"

// The sister-project field on a project's External Sites page (#5416).
// Once a value has been saved, the field shows what it resolved to --
// a link to the project on the external site, and how many of its
// observations are left to import -- rather than the id MO stored.
// Clearing it puts the empty input back so a different project can be
// named; the change is saved with the rest of the form.
// Connects to data-controller="remote-project"
export default class extends Controller {
  static targets = ["display", "entry", "input"]

  clear() {
    this.inputTarget.value = ""
    this.displayTarget.hidden = true
    this.entryTarget.hidden = false
    this.inputTarget.focus()
  }
}
