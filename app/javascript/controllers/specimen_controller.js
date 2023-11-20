import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="specimen"
export default class extends Controller {
  static targets = ["checkbox", "fields"]

  connect() {
    this.element.dataset.stimulus = "connected";

    this.showPref = this.element.dataset.userPref
    if (this.hasFieldsTarget && this.showPref) {
      this.hideShowFields()
    }
  }

  // Only show if user prefers
  hideShowFields() {
    if (this.checkboxTarget.checked) {
      this.fieldsTarget.classList.remove("hidden")
      $(this.fieldsTarget).show()
    } else {
      $(this.fieldsTarget).hide()
    }
  }

  // This checks "specimen" anyway if people add a CN or HR.
  checkCheckbox() {
    this.checkboxTarget.setAttribute("checked", true)
  }
}
