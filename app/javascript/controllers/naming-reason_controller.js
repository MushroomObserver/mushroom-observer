import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="naming-reason"
export default class extends Controller {
  static targets = ['collapse', 'input']

  connect() {
    this.element.dataset.stimulus = "connected";
  }

  focusInput(event) {
    console.log('Event fired on #' + event.currentTarget.id);
    this.inputTarget.focus()
  }
}
