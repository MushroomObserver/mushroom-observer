import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="checkbox-collapse"
export default class extends Controller {
  static targets = ["checkbox", "fields"]

  connect() {
    this.element.dataset.stimulus = "checkbox-collapse-connected";
  }

  // Only show if user prefers
  hideShowFields() {
    if (this.checkboxTarget.checked) {
      $(this.fieldsTarget).show()
    } else {
      $(this.fieldsTarget).hide()
    }
  }

  // Programmatically show or hide fields. To keep the checkbox in sync,
  // it also checks or unchecks the checkbox, in case called directly.
  hideFields() {
    $(this.fieldsTarget).hide()
    this.uncheckCheckbox()
  }

  showFields() {
    this.fieldsTarget.classList.remove("hidden")
    $(this.fieldsTarget).show()
    this.checkCheckbox()
  }

  // This checks "specimen" anyway if people add a CN or HR.
  checkCheckbox() {
    this.checkboxTarget.setAttribute("checked", true)
  }

  uncheckCheckbox() {
    this.checkboxTarget.removeAttribute("checked")
  }
}
