import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="qr-reader"
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.element.dataset.qrReader = "connected"

    // focus as soon as the input appears
    if (this.hasInputTarget)
      this.inputTarget.focus()
  }

  handleInput(event) {
    // Submits the form to a rails controller action that receives the input,
    // figures out if it's a URL or just a text string, sanitizes and redirects.
  }
}
