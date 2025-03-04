import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="donate"
export default class extends Controller {
  static targets = ['otherCheck', 'otherAmount']

  connect() {
    this.element.dataset.stimulus = "donate-connected";
  }

  checkOther() {
    this.otherCheckTarget.checked = true;
  }

  convert() {
    this.otherAmountTarget.value =
      this.otherAmountTarget.value.replace(/[^0-9]/g, '')
  }
}
