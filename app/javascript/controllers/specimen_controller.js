import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="specimen"
export default class extends Controller {
  static targets = ["info", "checkbox"]

  connect() {
    this.showPref = this.element.dataset.userPref
    this.hideShowFields()
  }

  // Only show if user prefers
  hideShowFields() {
    if (this.showPref) {
      if (this.checkboxTarget.checked) {
        this.infoTarget.classList.remove("hidden")
        $(this.infoTarget).show()
      } else {
        $(this.infoTarget).hide()
      }
    }
  }

  // This checks "specimen" anyway if people add a CN or HR.
  checkCheckbox() {
    this.checkboxTarget.setAttribute("checked", true)
  }
}
