import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clear-fields"
// Blanks every `field` target on click -- for a "Clear" button next
// to a form's submit button that empties all inputs without
// submitting (a native type="reset" button would revert to the
// server-rendered prefilled values instead of blanking them).
export default class extends Controller {
  static targets = ["field"]

  clear() {
    this.fieldTargets.forEach((field) => { field.value = "" })
  }
}
