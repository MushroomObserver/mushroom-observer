import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="naming-reason"
export default class extends Controller {
  static targets = ['collapse', 'input']

  connect() {
    this.element.setAttribute("data-stimulus", "connected")
  }

  focusInput() {
    alert("whao")
    this.inputTarget.focus()
  }
}
