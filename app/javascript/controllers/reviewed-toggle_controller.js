import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reviewed-toggle", on a wrapper div
// (not the form -- it can also carry a stretched-link data-action).
export default class extends Controller {
  static targets = ['toggle', 'form']

  connect() {
    this.element.dataset.reviewedToggle = "connected";
  }

  // https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
  submitForm() {
    this.formTarget.requestSubmit();
  }

  // A click on the label itself already natively toggles the
  // checkbox via its for= attribute -- only handle clicks elsewhere
  // in the stretched area, or this double-toggles back to unchecked.
  toggleCheckbox(event) {
    if (event.target.closest(".custom-control-label")) return;

    this.toggleTarget.checked = !this.toggleTarget.checked;
    // Stimulus's default action event for an <input> is "input", not
    // "change" -- a real checkbox toggle fires both; match that.
    this.toggleTarget.dispatchEvent(new Event("input", { bubbles: true }));
    this.toggleTarget.dispatchEvent(new Event("change", { bubbles: true }));
  }
}
