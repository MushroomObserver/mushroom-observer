import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reviewed-toggle"
// The element is the form, the toggle is an input
export default class extends Controller {
  static targets = ['toggle']

  connect() {
    this.element.dataset.stimulus = "connected";
  }

  // https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
  submitForm() {
    this.element.requestSubmit();
  }
}
