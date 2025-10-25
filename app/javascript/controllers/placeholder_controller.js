import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="placeholder"
export default class extends Controller {
  static targets = ['textField', 'select']

  connect() {
    this.element.dataset.placeholder = "connected";
    this.placeholders = JSON.parse(this.element.dataset.placeholders)
  }

  update() {
    const e = this.selectTarget,
      value = e.options[e.selectedIndex].label,
      new_ph = this.placeholders[value]
    this.textFieldTarget.setAttribute("placeholder", new_ph)
  }
}
